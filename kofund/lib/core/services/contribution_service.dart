// lib/core/services/contribution_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/contributions/models/contribution_model.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_types.dart';
import 'package:intl/intl.dart';

class ContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------
  // ➕ Create
  // -------------------------------
  Future<String> addContribution(ContributionModel contribution) async {
    try {
      final docRef = await _firestore.collection('contributions').add(contribution.toMap());
      
      // 🔔 Trigger User Notification (Contribution Added for Me)
      try {
        final notificationService = NotificationService();
        
        // Fetch program name for body
        String programName = 'Program';
        try {
          final programDoc = await _firestore.collection('programs').doc(contribution.programId).get();
          if (programDoc.exists) {
            programName = programDoc.data()?['title'] ?? 'Program';
          }
        } catch (_) {}

        final title = '₹${contribution.amount.toStringAsFixed(0)} Recorded ✅';
        final body = contribution.isMonthlyContribution && contribution.monthId != null 
            ? '${contribution.monthDisplayName} contribution · $programName' 
            : programName;

        // C. Running total for detailed screen
        double totalPaidSoFar = 0;
        double totalDue = 0;
        try {
          totalPaidSoFar = await getUserProgramTotalContributions(contribution.programId, contribution.userId);
          final programDoc = await _firestore.collection('programs').doc(contribution.programId).get();
          if (programDoc.exists) {
            totalDue = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
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
            'amountRecorded': '₹${contribution.amount.toStringAsFixed(0)}',
            'programName': programName,
            'period': contribution.monthDisplayName ?? 'N/A',
            'recordedBy': recorderName,
            'senderName': recorderName,
            'runningTotal': '₹${totalPaidSoFar.toStringAsFixed(0)} / ₹${totalDue.toStringAsFixed(0)}',
            'programId': contribution.programId,
            'timestamp': DateFormat('MMM dd, yyyy · hh:mm a').format(DateTime.now()),
          },
        );
      } catch (e) {
        debugPrint('⚠️ Contribution notification failed: $e');
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add contribution: $e');
    }
  }

  // -------------------------------
  // 🔍 Read (Program-based)
  // -------------------------------
  Future<List<ContributionModel>> getProgramContributions(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load program contributions: $e');
    }
  }

  // 👤 Read (User-based for specific program)
  Future<List<ContributionModel>> getUserProgramContributions(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load user contributions: $e');
    }
  }

  // 👤 Read (User-based for entire community)
  Future<List<ContributionModel>> getUserContributions(String userId, String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load user contributions: $e');
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

      // ✅ OPTIMIZED: Batch fetch all programs at once
      final programIds = contributionSnapshot.docs
          .map((doc) => doc.data()['programId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> programDataMap = {};
      if (programIds.isNotEmpty) {
        for (var i = 0; i < programIds.length; i += 30) {
          final chunk = programIds.sublist(i, (i + 30) > programIds.length ? programIds.length : (i + 30));
          final programsQuery =
              await _firestore.collection('programs').where(FieldPath.documentId, whereIn: chunk).get();
          for (var doc in programsQuery.docs) {
            programDataMap[doc.id] = doc.data();
          }
        }
      }

      final contributionHistory = <Map<String, dynamic>>[];

      for (final doc in contributionSnapshot.docs) {
        final contribution = doc.data();
        final programId = contribution['programId'] as String?;

        if (programId == null || programId.isEmpty) {
          continue;
        }

        final programData = programDataMap[programId];

        if (programData != null) {
          contributionHistory.add({
            'contributionId': doc.id,
            'programId': programId,
            'programTitle': programData['title'] ?? 'Unknown Program',
            'programDate': programData['programDate'],
            'programType': programData['programType'] ?? 'general',
            'amount': (contribution['amount'] ?? 0).toDouble(),
            'createdAt': contribution['createdAt'],
            'paidAt': contribution['paidAt'] ?? contribution['createdAt'],
            'paymentMethod': contribution['paymentMethod'] ?? 'cash',
            'suggestedContribution': (programData['suggestedContribution'] ?? 0).toDouble(),
            'communityId': communityId,
          });
        } else {
          // Still add contribution with basic info if program not found
          contributionHistory.add({
            'contributionId': doc.id,
            'programId': programId,
            'programTitle': 'Deleted Program',
            'programType': 'unknown',
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
      throw Exception('Failed to load community contributions: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getContributionsByUserAndProgram({
    required String userId,
    required String programId,
  }) async {
    try {
      final contributionSnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
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
  Future<double> getProgramTotalContributions(String programId) async {
    try {
      final snapshot = await _firestore.collection('contributions').where('programId', isEqualTo: programId).get();
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate total contributions: $e');
    }
  }

  Future<double> getUserProgramTotalContributions(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .get();
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate user total contributions: $e');
    }
  }

  Future<Map<String, dynamic>> getUserPaymentProgress(String programId, String userId) async {
    try {
      final totalPaid = await getUserProgramTotalContributions(programId, userId);
      final programDoc = await _firestore.collection('programs').doc(programId).get();

      if (!programDoc.exists) {
        throw Exception('Program not found');
      }

      final programData = programDoc.data()!;
      final suggestedAmount = (programData['suggestedContribution'] ?? 0).toDouble();
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
      final snapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .get();
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate user total contributions: $e');
    }
  }

  // -------------------------------
  // 📈 Analytics
  // -------------------------------
  Future<Map<String, dynamic>> getProgramPaymentSummary(String programId) async {
    try {
      final contributions = await getProgramContributions(programId);
      final programDoc = await _firestore.collection('programs').doc(programId).get();

      if (!programDoc.exists) {
        throw Exception('Program not found');
      }

      final programData = programDoc.data()!;
      final suggestedAmount = (programData['suggestedContribution'] ?? 0).toDouble();
      final currentParticipants = (programData['currentParticipants'] ?? 0) as int;

      double totalCollected = 0;
      final Map<String, double> userTotals = {};
      int fullyPaidUsers = 0;
      int partiallyPaidUsers = 0;

      for (final contribution in contributions) {
        totalCollected += contribution.amount;
        userTotals[contribution.userId] = (userTotals[contribution.userId] ?? 0) + contribution.amount;
      }

      userTotals.forEach((userId, totalPaid) {
        if (totalPaid >= suggestedAmount) {
          fullyPaidUsers++;
        } else if (totalPaid > 0) {
          partiallyPaidUsers++;
        }
      });

      int notPaidUsers = currentParticipants - (fullyPaidUsers + partiallyPaidUsers);

      return {
        'totalCollected': totalCollected,
        'expectedAmount': suggestedAmount * currentParticipants,
        'suggestedAmount': suggestedAmount,
        'fullyPaidUsers': fullyPaidUsers,
        'partiallyPaidUsers': partiallyPaidUsers,
        'notPaidUsers': notPaidUsers,
        'totalParticipants': currentParticipants,
        'collectionProgress':
            suggestedAmount * currentParticipants > 0 ? (totalCollected / (suggestedAmount * currentParticipants)) * 100 : 0,
        'userPaymentBreakdown': userTotals,
      };
    } catch (e) {
      throw Exception('Failed to get program payment summary: $e');
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
      final contributions = await getCommunityContributions(communityId);

      double totalAmount = 0;
      final Map<String, double> paymentMethodTotals = {};
      final Map<String, int> dailyContributions = {};

      for (final contribution in contributions) {
        totalAmount += contribution.amount;
        paymentMethodTotals[contribution.paymentMethod] =
            (paymentMethodTotals[contribution.paymentMethod] ?? 0) + contribution.amount;
        final dateKey = _formatDate(contribution.createdAt.toDate());
        dailyContributions[dateKey] = (dailyContributions[dateKey] ?? 0) + 1;
      }

      return {
        'totalContributions': contributions.length,
        'totalAmount': totalAmount,
        'averageContribution': contributions.isNotEmpty ? totalAmount / contributions.length : 0,
        'paymentMethodBreakdown': paymentMethodTotals,
        'dailyActivity': dailyContributions,
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
      final programIds = <String>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        paymentHistory.add({
          'contributionId': doc.id,
          'programId': data['programId'],
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
        });

        if (data['programId'] != null) {
          programIds.add(data['programId']);
        }
      }

      if (programIds.isNotEmpty) {
        final programsSnapshot =
            await _firestore.collection('programs').where(FieldPath.documentId, whereIn: programIds.toList()).get();

        final programMap = {
          for (var doc in programsSnapshot.docs)
            doc.id: {
              'title': doc.data()['title'] ?? 'Unknown Program',
              'programType': doc.data()['programType'] ?? 'general',
              'suggestedContribution': (doc.data()['suggestedContribution'] ?? 0).toDouble(),
            }
        };

        for (var contribution in paymentHistory) {
          final programId = contribution['programId'];
          if (programId != null && programMap.containsKey(programId)) {
            final programData = programMap[programId]!;
            contribution['programTitle'] = programData['title'];
            contribution['programType'] = programData['programType'];
            contribution['suggestedContribution'] = programData['suggestedContribution'];
          } else {
            contribution['programTitle'] = 'Program Not Found';
            contribution['programType'] = 'unknown';
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

      if (currentContribution.programId != contribution.programId) {
        changes['program'] = {
          'oldId': currentContribution.programId,
          'newId': contribution.programId,
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
          'programId': contribution.programId,
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
      }
    } catch (e) {
      throw Exception('Failed to update contribution: $e');
    }
  }

  Future<void> deleteContribution(String contributionId) async {
    try {
      await _firestore.collection('contributions').doc(contributionId).delete();
    } catch (e) {
      throw Exception('Failed to delete contribution: $e');
    }
  }

  // -------------------------------
  // 📡 Real-time Streams
  // -------------------------------
  Stream<List<ContributionModel>> streamProgramContributions(String programId) {
    return _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
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

  Stream<double> streamProgramTotalContributions(String programId) {
    return _firestore.collection('contributions').where('programId', isEqualTo: programId).snapshots().map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    });
  }

  Future<List<ContributionModel>> getMonthlyContributionsForProgram(String programId, String monthId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .where('monthId', isEqualTo: monthId)
          .where('isMonthlyContribution', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ContributionModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> hasUserPaidForMonth(String userId, String programId, String monthId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .where('monthId', isEqualTo: monthId)
          .where('isMonthlyContribution', isEqualTo: true)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, bool>> getMonthlyPaymentStatus(String programId, String monthId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .where('monthId', isEqualTo: monthId)
          .where('isMonthlyContribution', isEqualTo: true)
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