// lib/core/services/participant_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/participants/models/participant_model.dart';
import 'package:flutter/foundation.dart';

class ParticipantService {
  final FirebaseFirestore _firestore;

  ParticipantService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getMemberParticipationHistory(String memberId) async {
    try {
      debugPrint('🔍 ParticipantService: Getting participation history for member: $memberId');

      // FIRST: Get the user to get their communityId
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ ParticipantService: User $memberId not found in users collection');
        return [];
      }

      final userData = userDoc.data()!;
      final communityId = userData['communityId'];

      if (communityId == null || communityId.isEmpty) {
        debugPrint('⚠️ ParticipantService: User $memberId has no communityId');
        return [];
      }

      debugPrint('📊 ParticipantService: User belongs to community: $communityId');

      // Get all participants for this user IN THEIR COMMUNITY
      final participationSnapshot = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: memberId)
          .where('communityId', isEqualTo: communityId)
          .get();

      debugPrint('📊 ParticipantService: Found ${participationSnapshot.docs.length} participant documents');

      // Get all contributions for this user to calculate totals
      final contributionsSnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: memberId)
          .where('communityId', isEqualTo: communityId)
          .get();

      debugPrint('💰 ParticipantService: Found ${contributionsSnapshot.docs.length} contribution documents');

      // Group contributions by eventId
      final contributionsB = <String, double>{};
      for (final doc in contributionsSnapshot.docs) {
        final contribution = doc.data();
        final eventId = contribution['eventId'] as String?;
        final amount = (contribution['amount'] ?? 0).toDouble();

        if (eventId != null && eventId.isNotEmpty) {
          contributionsB[eventId] = (contributionsB[eventId] ?? 0) + amount;
        }
      }

      // ✅ OPTIMIZED: Batch fetch all events at once
      final ds = participationSnapshot.docs
          .map((doc) => doc.data()['eventId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> ataMap = {};
      if (ds.isNotEmpty) {
        try {
          for (var i = 0; i < ds.length; i += 30) {
            final chunk = ds.sublist(i, (i + 30) > ds.length ? ds.length : (i + 30));
            final eventsQuery = await _firestore
                .collection('events')
                .where('communityId', isEqualTo: communityId)
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (var doc in eventsQuery.docs) {
              ataMap[doc.id] = doc.data();
            }
          }
        } catch (e) {
          debugPrint('⚠️ ParticipantService: Batch event query failed, trying individual doc gets: $e');
          try {
            final futures = ds.map((id) => _firestore.collection('events').doc(id).get());
            final docs = await Future.wait(futures);
            for (var doc in docs) {
              if (doc.exists && doc.data() != null) {
                ataMap[doc.id] = doc.data()!;
              }
            }
          } catch (err) {
            debugPrint('❌ ParticipantService: Fallback individual event gets failed: $err');
          }
        }
      }

      final participationHistory = <Map<String, dynamic>>[];

      for (final doc in participationSnapshot.docs) {
        final participation = doc.data();
        final eventId = participation['eventId'] as String?;

        if (eventId == null || eventId.isEmpty) {
          debugPrint('⚠️ ParticipantService: Skipping participant without d');
          continue;
        }

        final data = ataMap[eventId];
        final totalPaid = contributionsB[eventId] ?? 0.0;
        
        // Use data from event document if available, otherwise fallback to participant document data
        final title = data?['title'] ?? participation['eventName'] ?? 'Unknown event';
        final eventDate = data?['eventDate'] ?? participation['joinedAt'];
        final eventType = data?['eventType'] ?? 'general';
        final suggestedContribution = (data?['suggestedContribution'] ?? 0).toDouble();
        
        final hasFullyPaid = suggestedContribution > 0 
            ? totalPaid >= suggestedContribution 
            : (participation['hasPaidContribution'] ?? false);

        participationHistory.add({
          'eventId': eventId,
          'title': title,
          'eventDate': eventDate,
          'eventType': eventType,
          'joinedAt': participation['joinedAt'],
          'status': participation['status'] ?? 'joined',
          'hasPaidContribution': hasFullyPaid,
          'contributionPaid': totalPaid,
          'suggestedContribution': suggestedContribution,
          'communityId': communityId,
        });
      }

      // Sort by joined date (newest first)
      participationHistory.sort((a, b) => (b['joinedAt'] as Timestamp).compareTo(a['joinedAt'] as Timestamp));

      debugPrint('✅ ParticipantService: Returning ${participationHistory.length} participation history items');
      return participationHistory;
    } catch (e) {
      debugPrint('❌ ParticipantService Error in getMemberParticipationHistory: $e');
      return [];
    }
  }

  // Get participant by eventId and userId
  Future<ParticipantModel> getParticipant(String eventId, String userId, {required String communityId}) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        throw Exception('Participant not found for event $eventId and user $userId');
      }
      final doc = snapshot.docs.first;
      return ParticipantModel.fromMap(doc.data(), doc.id);
    } catch (e) {
      debugPrint('❌ ParticipantService Error in getParticipant: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserParticipationHistoryWithContributions(String userId) async {
    try {
      debugPrint('🔍 ParticipantService.getUserParticipationHistoryWithContributions for: $userId');

      // Get user's community first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ User not found: $userId');
        return [];
      }

      final userData = userDoc.data()!;
      final communityId = userData['communityId'];

      if (communityId == null || communityId.isEmpty) {
        debugPrint('⚠️ User has no community: $userId');
        return [];
      }

      // Get all participants for this user
      final participationSnapshot = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .get();

      // Get all contributions for this user to calculate totals
      final contributionsSnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .get();

      // Group contributions by eventId
      final contributionsB = <String, double>{};
      for (final doc in contributionsSnapshot.docs) {
        final contribution = doc.data();
        final eventId = contribution['eventId'] as String?;
        final amount = (contribution['amount'] ?? 0).toDouble();

        if (eventId != null && eventId.isNotEmpty) {
          contributionsB[eventId] = (contributionsB[eventId] ?? 0) + amount;
        }
      }

      // ✅ OPTIMIZED: Batch fetch all events at once
      final ds = participationSnapshot.docs
          .map((doc) => doc.data()['eventId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> ataMap = {};
      if (ds.isNotEmpty) {
        try {
          for (var i = 0; i < ds.length; i += 30) {
            final chunk = ds.sublist(i, (i + 30) > ds.length ? ds.length : (i + 30));
            final eventsQuery = await _firestore
                .collection('events')
                .where('communityId', isEqualTo: communityId)
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (var doc in eventsQuery.docs) {
              ataMap[doc.id] = doc.data();
            }
          }
        } catch (e) {
          debugPrint('⚠️ ParticipantService: Batch event query failed, trying individual doc gets: $e');
          try {
            final futures = ds.map((id) => _firestore.collection('events').doc(id).get());
            final docs = await Future.wait(futures);
            for (var doc in docs) {
              if (doc.exists && doc.data() != null) {
                ataMap[doc.id] = doc.data()!;
              }
            }
          } catch (err) {
            debugPrint('❌ ParticipantService: Fallback individual event gets failed: $err');
          }
        }
      }

      final participationHistory = <Map<String, dynamic>>[];

      for (final doc in participationSnapshot.docs) {
        final participation = doc.data();
        final eventId = participation['eventId'] as String?;

        if (eventId == null || eventId.isEmpty) {
          continue;
        }

        final data = ataMap[eventId];
        final totalPaid = contributionsB[eventId] ?? 0.0;
        
        // Use data from event document if available, otherwise fallback to participant document data
        final title = data?['title'] ?? participation['eventName'] ?? 'Unknown event';
        final eventDate = data?['eventDate'] ?? participation['joinedAt'];
        final eventType = data?['eventType'] ?? 'general';
        final suggestedContribution = (data?['suggestedContribution'] ?? 0).toDouble();
        
        final hasFullyPaid = suggestedContribution > 0 
            ? totalPaid >= suggestedContribution 
            : (participation['hasPaidContribution'] ?? false);

        participationHistory.add({
          'participationId': doc.id,
          'eventId': eventId,
          'title': title,
          'eventDate': eventDate,
          'eventType': eventType,
          'joinedAt': participation['joinedAt'],
          'status': participation['status'] ?? 'joined',
          'hasPaidContribution': hasFullyPaid,
          'contributionPaid': totalPaid,
          'suggestedContribution': suggestedContribution,
          'progressPercentage': suggestedContribution > 0 ? (totalPaid / suggestedContribution) * 100 : 0,
        });
      }

      // Sort by joined date (newest first)
      participationHistory.sort((a, b) => (b['joinedAt'] as Timestamp).compareTo(a['joinedAt'] as Timestamp));

      return participationHistory;
    } catch (e) {
      debugPrint('❌ ParticipantService Error: $e');
      return [];
    }
  }

  Future<String> join(ParticipantModel participant) async {
    try {
      final existingSnapshot = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: participant.eventId)
          .where('userId', isEqualTo: participant.userId)
          .where('communityId', isEqualTo: participant.communityId)
          .get();
      if (existingSnapshot.docs.isNotEmpty) {
        final alreadyJoined = existingSnapshot.docs.any((doc) => doc['status'] == 'joined');
        if (alreadyJoined) {
          throw Exception('You have already joined this event');
        }
        final cancelledDocs = existingSnapshot.docs.where((doc) => doc['status'] == 'cancelled').toList();
        if (cancelledDocs.isNotEmpty) {
          final docToReuse = cancelledDocs.first;
          final existingData = docToReuse.data();
          final currentContributionPaid = existingData['contributionPaid'] ?? 0.0;
          final currentHasPaid = existingData['hasPaidContribution'] ?? false;
          await docToReuse.reference.update({
            'status': 'joined',
            'joinedAt': Timestamp.fromDate(participant.joinedAt),
            'userName': participant.userName,
            'userEmail': participant.userEmail,
            'contributionPaid': currentContributionPaid,
            'hasPaidContribution': currentHasPaid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          return docToReuse.id;
        }
      }
      final docRef = await _firestore.collection('participants').add(participant.toMap());
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to join event: $e');
    }
  }

  Future<void> leave(String eventId, String userId, {String? communityId}) async {
    try {
      var query = _firestore
          .collection('participants')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'joined');

      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final currentData = doc.data();
        await doc.reference.update({
          'status': 'cancelled',
          'contributionPaid': currentData['contributionPaid'] ?? 0.0,
          'hasPaidContribution': currentData['hasPaidContribution'] ?? false,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to leave event: $e');
    }
  }

  Future<String> addParticipant(ParticipantModel participant) async {
    try {
      final existingSnapshot = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: participant.eventId)
          .where('userId', isEqualTo: participant.userId)
          .where('communityId', isEqualTo: participant.communityId)
          .where('status', isEqualTo: 'joined')
          .get();
      if (existingSnapshot.docs.isNotEmpty) {
        throw Exception('User is already a participant in this event');
      }
      final cancelledSnapshot = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: participant.eventId)
          .where('userId', isEqualTo: participant.userId)
          .where('communityId', isEqualTo: participant.communityId)
          .where('status', isEqualTo: 'cancelled')
          .get();
      if (cancelledSnapshot.docs.isNotEmpty) {
        final docToReuse = cancelledSnapshot.docs.first;
        final existingData = docToReuse.data();
        await docToReuse.reference.update({
          'status': 'joined',
          'joinedAt': Timestamp.fromDate(participant.joinedAt),
          'userName': participant.userName,
          'userEmail': participant.userEmail,
          'contributionPaid': existingData['contributionPaid'] ?? 0.0,
          'hasPaidContribution': existingData['hasPaidContribution'] ?? false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return docToReuse.id;
      }
      final docRef = await _firestore.collection('participants').add(participant.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add participant: $e');
    }
  }

  Future<List<ParticipantModel>> getUseParticipations(String userId, String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .get();
      return snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load participations: $e');
    }
  }

  Future<List<ParticipantModel>> getEventParticipants(String eventId, {required String communityId}) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: eventId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .get();
      return snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load event participants: $e');
    }
  }

  Future<bool> hasUserJoinedEvent(String eventId, String userId, {required String communityId}) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check participation: $e');
    }
  }

  Future<int> getParticipantCount(String eventId, {required String communityId}) async {
    try {
      final aggregateQuery = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: eventId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .count()
          .get();
      return aggregateQuery.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get participant count: $e');
    }
  }

  Stream<int> streamEventParticipantCount(String eventId, {String? communityId}) {
    if (communityId == null || communityId.isEmpty) {
      debugPrint('⚠️ streamEventParticipantCount: communityId is null or empty for event $eventId');
      return Stream.value(0);
    }

    var query = _firestore
        .collection('participants')
        .where('eventId', isEqualTo: eventId)
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'joined');

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<List<ParticipantModel>> streamUseParticipations(String userId, String communityId) {
    return _firestore
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<ParticipantModel>> streamParticipants(String eventId, {String? communityId}) {
    if (communityId == null || communityId.isEmpty) {
      debugPrint('⚠️ streamParticipants: communityId is null or empty for event $eventId');
      return Stream.value([]);
    }

    var query = _firestore
        .collection('participants')
        .where('eventId', isEqualTo: eventId)
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'joined');

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> updatePaymentStatus(String participantId, double amountPaid, bool hasFullyPaid) async {
    try {
      await _firestore.collection('participants').doc(participantId).update({
        'contributionPaid': amountPaid,
        'hasPaidContribution': hasFullyPaid,
      });
    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  Future<ParticipantModel?> getParticipantById(String participantId) async {
    try {
      final doc = await _firestore.collection('participants').doc(participantId).get();
      if (doc.exists) {
        return ParticipantModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get participant: $e');
    }
  }

  Future<ParticipantModel?> getParticipantBAndUser(String eventId, String userId, {required String communityId}) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ParticipantModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get participant: $e');
    }
  }

  Future<void> updateParticipant(String participantId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('participants').doc(participantId).update(updates);
    } catch (e) {
      throw Exception('Failed to update participant: $e');
    }
  }

  Future<List<ParticipantModel>> getAllUserParticipations(String userId, {String? communityId}) async {
    try {
      var query = _firestore.collection('participants').where('userId', isEqualTo: userId);
      
      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load all user participations: $e');
    }
  }

  Future<void> updateParticipantContribution(String userId, String eventId, {String? communityId}) async {
    try {
      var query = _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId);

      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      final aggregateQuery = await query.aggregate(sum('amount')).get();

      double totalPaid = (aggregateQuery.getSum('amount') ?? 0).toDouble();

      final doc = await _firestore.collection('events').doc(eventId).get();
      final suggestedContribution =
          doc.exists ? (doc.data()!['suggestedContribution'] ?? 0).toDouble() : 0.0;

      var participantQuery = _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId);
      
      if (communityId != null && communityId.isNotEmpty) {
        participantQuery = participantQuery.where('communityId', isEqualTo: communityId);
      }

      final snapshot = await participantQuery.get();

      if (snapshot.docs.isNotEmpty) {
        final participantDoc = snapshot.docs.first;
        await participantDoc.reference.update({
          'contributionPaid': totalPaid,
          'hasPaidContribution': totalPaid >= suggestedContribution,
          'updatedAt': Timestamp.now(),
        });
      }
    } catch (e) {
      throw Exception('Failed to update participant contribution: $e');
    }
  }
}




