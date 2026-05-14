// lib/core/services/contribution_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/contributions/models/contribution_model.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/services/participant_service.dart';

class ContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------
  // ➕ Create
  // -------------------------------
  Future<String> addContribution(ContributionModel contribution, {String? name}) async {
    try {
      final docRef = await _firestore.collection('contributions').add(contribution.toMap());
      
      // 🔔 Trigger User Notification (Contribution Added for Me)
      try {
        final notificationService = NotificationService();
        
        // 🚀 OPTIMIZATION: Use passed name to avoid extra read
        String pName = name ?? 'event';
        if (name == null) {
          try {
            final doc = await _firestore.collection('events').doc(contribution.eventId).get();
            if (doc.exists) {
              pName = doc.data()?['title'] ?? 'event';
            }
          } catch (_) {}
        }

        final title = '₹${contribution.amount.toStringAsFixed(0)} Recorded ✅';
        final body = contribution.isMonthlyContribution && contribution.monthId != null 
            ? '${contribution.monthDisplayName} contribution · $pName' 
            : pName;

        // C. Running total for detailed screen - 🚀 Use optimized total fetch
        double totalPaidSoFar = 0;
        double totalDue = 0;
        try {
          totalPaidSoFar = await getUseTotalContributions(contribution.eventId, contribution.userId);
          final doc = await _firestore.collection('events').doc(contribution.eventId).get();
          if (doc.exists) {
            totalDue = (doc.data()?['suggestedContribution'] ?? 0).toDouble();
          }
        } catch (_) {}

        final recorderName = contribution.addedByUserName ?? 'Admin';

        await notificationService.sendUserNotification(
          userId: contribution.userId,
          title: title,
          body: body,
          type: NotificationType.contribution,
          senderName: recorderName,
          data: {
            'contributionId': docRef.id,
            'aamountRecorded': '₹${contribution.amount.toStringAsFixed(0)}',
            'name': pName, // ✅ Fix: Use fetched/calculated pName
            'period': contribution.monthDisplayName.isNotEmpty 
                ? contribution.monthDisplayName 
                : 'General contribution', // ✅ Fix: Handle non-monthly period
            'recordedBy': recorderName,
            'senderName': recorderName,
            'runningTotal': '₹${totalPaidSoFar.toStringAsFixed(0)}',
            'targetAmount': '₹${totalDue.toStringAsFixed(0)}',
            'eventId': contribution.eventId,
            'timestamp': DateFormat('MMM dd, yyyy · hh:mm a').format(DateTime.now()),
          },
        );
      } catch (e) {
        debugPrint('⚠️ Contribution notification failed: $e');
      }

      // ✅ NEW: Update participant's summary in Firestore
      try {
        final participantService = ParticipantService();
        await participantService.updateParticipantContribution(contribution.userId, contribution.eventId);
        debugPrint('✅ Participant payment status updated');
      } catch (e) {
        debugPrint('⚠️ Failed to update participant summary: $e');
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add contribution: $e');
    }
  }

  // -------------------------------
  // 🔍 Read (event-based)
  // -------------------------------
  Future<List<ContributionModel>> getContributions(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId)
          .get();
      final docs = snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
      // Sort in memory to avoid index requirements
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    } catch (e) {
      debugPrint('⚠️ Error loading event contributions: $e');
      return [];
    }
  }

  // 👤 Read (User-based for specific event)
  Future<List<ContributionModel>> getUseContributions(String eventId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .get();
      final docs = snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    } catch (e) {
      debugPrint('⚠️ Error loading user event contributions: $e');
      return [];
    }
  }

  // 👤 Read (User-based for entire community)
  Future<List<ContributionModel>> getUserContributions(String userId, String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .get();
      final docs = snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    } catch (e) {
      debugPrint('⚠️ Error loading user contributions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMemberContributionHistory(String memberId) async {
    try {
      debugPrint('🔍 ContributionService: Getting contribution history for member: $memberId');

      // FIRST: Get the user to get their communityId
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ ContributionService: User $memberId not found in users collection');
        return [];
      }

      final userData = userDoc.data()!;
      final communityId = userData['communityId'];

      if (communityId == null || communityId.isEmpty) {
        debugPrint('⚠️ ContributionService: User $memberId has no communityId');
        return [];
      }

      // Get all contributions for this user IN THEIR COMMUNITY
      final contributionSnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: memberId)
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();

      // ✅ OPTIMIZED: Batch fetch all events at once
      final ds = contributionSnapshot.docs
          .map((doc) => doc.data()['eventId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> ataMap = {};
      if (ds.isNotEmpty) {
        for (var i = 0; i < ds.length; i += 30) {
          final chunk = ds.sublist(i, (i + 30) > ds.length ? ds.length : (i + 30));
          final eventsQuery =
              await _firestore.collection('events').where(FieldPath.documentId, whereIn: chunk).get();
          for (var doc in eventsQuery.docs) {
            ataMap[doc.id] = doc.data();
          }
        }
      }

      final contributionHistory = <Map<String, dynamic>>[];

      for (final doc in contributionSnapshot.docs) {
        final contribution = doc.data();
        final eventId = contribution['eventId'] as String?;

        if (eventId == null || eventId.isEmpty) {
          continue;
        }

        final data = ataMap[eventId];

        if (data != null) {
          contributionHistory.add({
            'contributionId': doc.id,
            'eventId': eventId,
            'title': data['title'] ?? contribution['eventName'] ?? 'Unknown event',
            'eventDate': data['eventDate'],
            'eventType': data['eventType'] ?? 'general',
            'amount': (contribution['amount'] ?? 0).toDouble(),
            'createdAt': contribution['createdAt'],
            'paidAt': contribution['paidAt'] ?? contribution['createdAt'],
            'paymentMethod': contribution['paymentMethod'] ?? 'cash',
            'suggestedContribution': (data['suggestedContribution'] ?? 0).toDouble(),
            'communityId': communityId,
          });
        } else {
          // Still add contribution with basic info if event not found
          contributionHistory.add({
            'contributionId': doc.id,
            'eventId': eventId,
            'title': contribution['eventName'] ?? 'Deleted event',
            'eventType': 'unknown',
            'amount': (contribution['amount'] ?? 0).toDouble(),
            'createdAt': contribution['createdAt'],
            'paidAt': contribution['paidAt'] ?? contribution['createdAt'],
            'paymentMethod': contribution['paymentMethod'] ?? 'cash',
            'suggestedContribution': 0,
            'communityId': communityId,
          });
        }
      }
      return contributionHistory;
    } catch (e) {
      debugPrint('❌ ContributionService Error: $e');
      return [];
    }
  }

  // 🏛️ Read (Admin - all contributions in a community)
  Future<List<ContributionModel>> getCommunityContributions(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load contributions by user and event: $e');
    }
  }



  Future<List<Map<String, dynamic>>> getContributionsByUserAn({
    required String userId,
    required String eventId,
  }) async {
    try {
      final contributionSnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId)
          .get();

      return contributionSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'contributionId': doc.id,
          'amount': (data['amount'] ?? 0).toDouble(),
          'createdAt': data['createdAt'],
          'paidAt': data['paidAt'] ?? data['createdAt'],
          'paymentMethod': data['paymentMethod'] ?? 'cash',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ ContributionService Error: $e');
      return [];
    }
  }

  // -------------------------------
  // 📊 Calculations
  // -------------------------------
  Future<double> getTotalContributions(String eventId) async {
    try {
      // 🚀 OPTIMIZATION: Use aggregate query (sum)
      final aggregateQuery = await _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId)
          .aggregate(sum('amount'))
          .get();
      final total = (aggregateQuery.getSum('amount') ?? 0).toDouble();
      
      // Fallback: If 0 but we want to be absolutely sure (e.g. during migration)
      if (total == 0) {
        final docs = await getContributions(eventId);
        return docs.fold<double>(0.0, (sum, c) => sum + c.amount);
      }
      
      return total;
    } catch (e) {
      // Final fallback
      final docs = await getContributions(eventId);
      return docs.fold<double>(0.0, (sum, c) => sum + c.amount);
    }
  }

  Future<double> getUseTotalContributions(String eventId, String userId) async {
    try {
      // 🚀 OPTIMIZATION: Use aggregate query (sum)
      final aggregateQuery = await _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .aggregate(sum('amount'))
          .get();
      final total = (aggregateQuery.getSum('amount') ?? 0).toDouble();
      
      if (total == 0) {
        final docs = await getUseContributions(eventId, userId);
        return docs.fold<double>(0.0, (sum, c) => sum + c.amount);
      }
      return total;
    } catch (e) {
      final docs = await getUseContributions(eventId, userId);
      return docs.fold<double>(0.0, (sum, c) => sum + c.amount);
    }
  }

  Future<Map<String, dynamic>> getUserPaymentProgress(String eventId, String userId) async {
    try {
      final totalPaid = await getUseTotalContributions(eventId, userId);
      final doc = await _firestore.collection('events').doc(eventId).get();

      if (!doc.exists) {
        throw Exception('event not found');
      }

      final data = doc.data()!;
      final suggestedAmount = (data['suggestedContribution'] ?? 0).toDouble();
      final remainingAmount = suggestedAmount - totalPaid;
      final progressPercentage = suggestedAmount > 0 ? (totalPaid / suggestedAmount) * 100 : 0;

      return {
        'totalPaid': totalPaid,
        'suggestedAmount': suggestedAmount,
        'remainingAmount': remainingAmount > 0 ? remainingAmount : 0,
        'progressPercentage': progressPercentage,
        'isFullyPaid': totalPaid >= suggestedAmount,
        'isOverpaid': totalPaid > suggestedAmount,
      };
    } catch (e) {
      throw Exception('Failed to get payment progress: $e');
    }
  }

  Future<double> getUserTotalContributions(String userId, String communityId) async {
    try {
      // 🚀 OPTIMIZATION: Use aggregate query (sum) instead of reading docs
      final aggregateQuery = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .aggregate(sum('amount'))
          .get();
      return (aggregateQuery.getSum('amount') ?? 0).toDouble();
    } catch (e) {
      throw Exception('Failed to calculate user total contributions: $e');
    }
  }

  // -------------------------------
  // 📈 Analytics
  // -------------------------------
  Future<Map<String, dynamic>> getPaymentSummary(String eventId) async {
    try {
      final totalCollected = await getTotalContributions(eventId);
      final doc = await _firestore.collection('events').doc(eventId).get();

      if (!doc.exists) {
        throw Exception('event not found');
      }

      final data = doc.data()!;
      final suggestedAmount = (data['suggestedContribution'] ?? 0).toDouble();
      final currentParticipants = (data['currentParticipants'] ?? 0) as int;

      // Note: For detailed breakdown of fully/partially paid users, 
      // we still might need some logic, but for general summary, 
      // simple aggregation is much cheaper.
      
      return {
        'totalCollected': totalCollected,
        'expectedAmount': suggestedAmount * currentParticipants,
        'suggestedAmount': suggestedAmount,
        'totalParticipants': currentParticipants,
        'collectionProgress':
            suggestedAmount * currentParticipants > 0 ? (totalCollected / (suggestedAmount * currentParticipants)) * 100 : 0,
      };
    } catch (e) {
      throw Exception('Failed to get event payment summary: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTopContributors(String communityId, {int limit = 10}) async {
    try {
      final contributions = await getCommunityContributions(communityId);
      final Map<String, double> userTotals = {};

      for (final contribution in contributions) {
        userTotals[contribution.userId] = (userTotals[contribution.userId] ?? 0) + contribution.amount;
      }

      final contributorList = userTotals.entries
          .map((entry) => {
                'userId': entry.key,
                'totalAmount': entry.value,
                'contributionCount': contributions.where((c) => c.userId == entry.key).length,
              })
          .toList();

      contributorList.sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));

      return contributorList.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get top contributors: $e');
    }
  }

  Future<Map<String, dynamic>> getCommunityPaymentStats(String communityId) async {
    try {
      // 🚀 OPTIMIZATION: Use aggregations for large-scale data
      final totalQuery = await _firestore
          .collection('contributions')
          .where('communityId', isEqualTo: communityId)
          .aggregate(sum('amount'), count())
          .get();

      final totalAmount = (totalQuery.getSum('amount') ?? 0).toDouble();
      final countValue = totalQuery.count ?? 0;

      return {
        'totalContributions': countValue,
        'totalAmount': totalAmount,
        'averageContribution': countValue > 0 ? totalAmount / countValue : 0,
        'lastUpdated': Timestamp.now(),
      };
    } catch (e) {
      throw Exception('Failed to get payment statistics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserPaymentHistoryWithDetails(String userId, String communityId) async {
    try {
      final querySnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final paymentHistory = <Map<String, dynamic>>[];
      final ds = <String>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        paymentHistory.add({
          'contributionId': doc.id,
          'eventId': data['eventId'],
          'amount': data['amount'],
          'paymentMethod': data['paymentMethod'],
          'status': data['status'],
          'createdAt': data['createdAt'],
          'isEdited': data['isEdited'] ?? false,
          'editHistory': data['editHistory'] ?? [],
          'lastEditedByUserName': data['lastEditedByUserName'],
          'editReason': data['editReason'],
          'isMonthlyContribution': data['isMonthlyContribution'] ?? false,
          'monthId': data['monthId'],
          'addedByUserName': data['addedByUserName'],
          'communityId': data['communityId'] ?? communityId,
          'contributorName': data['contributorName'],
          'eventName': data['eventName'],
        });

        if (data['eventId'] != null) {
          ds.add(data['eventId']);
        }
      }

      if (ds.isNotEmpty) {
        final eventsSnapshot =
            await _firestore.collection('events').where(FieldPath.documentId, whereIn: ds.toList()).get();

        final ap = {
          for (var doc in eventsSnapshot.docs)
            doc.id: {
              'title': doc.data()['title'] ?? 'Unknown event',
              'eventType': doc.data()['eventType'] ?? 'general',
              'suggestedContribution': (doc.data()['suggestedContribution'] ?? 0).toDouble(),
            }
        };

        for (var contribution in paymentHistory) {
          final eventId = contribution['eventId'];
          if (eventId != null && ap.containsKey(eventId)) {
            final data = ap[eventId]!;
            contribution['title'] = data['title'];
            contribution['eventType'] = data['eventType'];
            contribution['suggestedContribution'] = data['suggestedContribution'];
          } else {
            contribution['title'] = contribution['eventName'] ?? 'event Not Found';
            contribution['eventType'] = 'unknown';
            contribution['suggestedContribution'] = 0;
          }
        }
      }
      return paymentHistory;
    } catch (e) {
      debugPrint('❌ ContributionService Error: $e');
      return [];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // -------------------------------
  // 🔄 Update / Delete
  // -------------------------------
  Future<void> updateContribution(
    ContributionModel contribution, {
    required String editedByUserId,
    required String editedByUserName,
    String? editReason,
  }) async {
    try {
      final docRef = _firestore.collection('contributions').doc(contribution.contributionId);
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        throw Exception('Contribution document not found');
      }

      final currentData = snapshot.data()!;
      final currentContribution = ContributionModel.fromMap(currentData, snapshot.id);

      final Map<String, Map<String, dynamic>> changes = {};

      if (currentContribution.amount != contribution.amount) {
        changes['amount'] = {'old': currentContribution.amount, 'new': contribution.amount};
      }

      if (currentContribution.paymentMethod != contribution.paymentMethod) {
        changes['paymentMethod'] = {'old': currentContribution.paymentMethod, 'new': contribution.paymentMethod};
      }

      if (currentContribution.contributionId != contribution.contributionId) {
        changes['event'] = {
          'oldId': currentContribution.contributionId,
          'newId': contribution.contributionId,
        };
      }

      if (changes.isNotEmpty) {
        List<dynamic> existingHistory = List.from(currentData['editHistory'] ?? []);
        existingHistory.add({
          'editedAt': Timestamp.now(),
          'editedByUserId': editedByUserId,
          'editedByUserName': editedByUserName,
          'changes': changes,
          'reason': editReason ?? '',
        });

        await docRef.update({
          'amount': contribution.amount,
          'paymentMethod': contribution.paymentMethod,
          'eventId': contribution.eventId,
          'userId': contribution.userId,
          'isMonthlyContribution': contribution.isMonthlyContribution,
          'monthId': contribution.monthId,
          'isEdited': true,
          'lastEditedByUserId': editedByUserId,
          'lastEditedByUserName': editedByUserName,
          'lastEditedAt': Timestamp.now(),
          'editReason': editReason,
          'editHistory': existingHistory,
          'updatedAt': Timestamp.now(),
        });

        // ✅ NEW: Update participant's summary in Firestore
        try {
          final participantService = ParticipantService();
          await participantService.updateParticipantContribution(contribution.userId, contribution.eventId);
          debugPrint('✅ Participant payment status updated after edit');
        } catch (e) {
          debugPrint('⚠️ Failed to update participant summary after edit: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to update contribution: $e');
    }
  }

  Future<void> deleteContribution(String contributionId) async {
    try {
      // Get contribution data first to know userId and eventId
      final doc = await _firestore.collection('contributions').doc(contributionId).get();
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final userId = data['userId'] as String;
      final eventId = data['eventId'] as String;

      await _firestore.collection('contributions').doc(contributionId).delete();

      // ✅ NEW: Update participant's summary in Firestore
      try {
        final participantService = ParticipantService();
        await participantService.updateParticipantContribution(userId, eventId);
        debugPrint('✅ Participant payment status updated after deletion');
      } catch (e) {
        debugPrint('⚠️ Failed to update participant summary after deletion: $e');
      }
    } catch (e) {
      throw Exception('Failed to delete contribution: $e');
    }
  }

  // -------------------------------
  // 📡 Real-time Streams
  // -------------------------------
  Stream<List<ContributionModel>> streamContributions(String eventId) {
    return _firestore
        .collection('contributions')
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<ContributionModel>> streamUserContributions(String userId, String communityId) {
    return _firestore
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<ContributionModel>> streamCommunityContributions(String communityId) {
    return _firestore
        .collection('contributions')
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<double> streamTotalContributions(String eventId) {
    return _firestore
        .collection('contributions')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .asyncMap((_) async {
          return await getTotalContributions(eventId);
        });
  }

  Future<List<ContributionModel>> getMonthlyContributionsFo(String eventId, String monthId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId)
          .where('monthId', isEqualTo: monthId)
          .get();
      final docs = snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    } catch (e) {
      return [];
    }
  }

  Future<bool> hasUserPaidForMonth(String userId, String eventId, String monthId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId)
          .where('monthId', isEqualTo: monthId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, bool>> getMonthlyPaymentStatus(String eventId, String monthId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId)
          .where('monthId', isEqualTo: monthId)
          .get();

      final Map<String, bool> statusMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        if (userId != null) {
          statusMap[userId] = true;
        }
      }
      return statusMap;
    } catch (e) {
      debugPrint('❌ Error in getMonthlyPaymentStatus: $e');
      return {};
    }
  }
}




