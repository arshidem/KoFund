// lib/core/services/participant_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/participants/models/participant_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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

      // Group contributions by programId
      final contributionsByProgram = <String, double>{};
      for (final doc in contributionsSnapshot.docs) {
        final contribution = doc.data();
        final programId = contribution['programId'] as String?;
        final amount = (contribution['amount'] ?? 0).toDouble();

        if (programId != null && programId.isNotEmpty) {
          contributionsByProgram[programId] = (contributionsByProgram[programId] ?? 0) + amount;
        }
      }

      // ✅ OPTIMIZED: Batch fetch all programs at once
      final programIds = participationSnapshot.docs
          .map((doc) => doc.data()['programId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> programDataMap = {};
      if (programIds.isNotEmpty) {
        for (var i = 0; i < programIds.length; i += 30) {
          final chunk = programIds.sublist(i, (i + 30) > programIds.length ? programIds.length : (i + 30));
          final programsQuery = await _firestore
              .collection('programs')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in programsQuery.docs) {
            programDataMap[doc.id] = doc.data();
          }
        }
      }

      final participationHistory = <Map<String, dynamic>>[];

      for (final doc in participationSnapshot.docs) {
        final participation = doc.data();
        final programId = participation['programId'] as String?;

        if (programId == null || programId.isEmpty) {
          debugPrint('⚠️ ParticipantService: Skipping participant without programId');
          continue;
        }

        final programData = programDataMap[programId];

        if (programData != null) {
          final suggestedContribution = (programData['suggestedContribution'] ?? 0).toDouble();
          final totalPaid = contributionsByProgram[programId] ?? 0.0;
          final hasFullyPaid = suggestedContribution > 0 && totalPaid >= suggestedContribution;

          participationHistory.add({
            'programId': programId,
            'programTitle': programData['title'] ?? 'Unknown Program',
            'programDate': programData['programDate'],
            'programType': programData['programType'] ?? 'general',
            'joinedAt': participation['joinedAt'],
            'status': participation['status'] ?? 'joined',
            'hasPaidContribution': hasFullyPaid,
            'contributionPaid': totalPaid,
            'suggestedContribution': suggestedContribution,
            'communityId': communityId,
          });
        } else {
          debugPrint('⚠️ ParticipantService: Program $programId not found');
        }
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

  // Get participant by programId and userId
  Future<ParticipantModel> getParticipant(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'joined')
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        throw Exception('Participant not found for program $programId and user $userId');
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

      // Group contributions by programId
      final contributionsByProgram = <String, double>{};
      for (final doc in contributionsSnapshot.docs) {
        final contribution = doc.data();
        final programId = contribution['programId'] as String?;
        final amount = (contribution['amount'] ?? 0).toDouble();

        if (programId != null && programId.isNotEmpty) {
          contributionsByProgram[programId] = (contributionsByProgram[programId] ?? 0) + amount;
        }
      }

      // ✅ OPTIMIZED: Batch fetch all programs at once
      final programIds = participationSnapshot.docs
          .map((doc) => doc.data()['programId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> programDataMap = {};
      if (programIds.isNotEmpty) {
        for (var i = 0; i < programIds.length; i += 30) {
          final chunk = programIds.sublist(i, (i + 30) > programIds.length ? programIds.length : (i + 30));
          final programsQuery = await _firestore
              .collection('programs')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in programsQuery.docs) {
            programDataMap[doc.id] = doc.data();
          }
        }
      }

      final participationHistory = <Map<String, dynamic>>[];

      for (final doc in participationSnapshot.docs) {
        final participation = doc.data();
        final programId = participation['programId'] as String?;

        if (programId == null || programId.isEmpty) {
          continue;
        }

        final programData = programDataMap[programId];
        if (programData != null) {
          final suggestedContribution = (programData['suggestedContribution'] ?? 0).toDouble();
          final totalPaid = contributionsByProgram[programId] ?? 0.0;
          final hasFullyPaid = suggestedContribution > 0 && totalPaid >= suggestedContribution;

          participationHistory.add({
            'participationId': doc.id,
            'programId': programId,
            'programTitle': programData['title'] ?? 'Unknown Program',
            'programDate': programData['programDate'],
            'programType': programData['programType'] ?? 'general',
            'joinedAt': participation['joinedAt'],
            'status': participation['status'] ?? 'joined',
            'hasPaidContribution': hasFullyPaid,
            'contributionPaid': totalPaid,
            'suggestedContribution': suggestedContribution,
            'progressPercentage': suggestedContribution > 0 ? (totalPaid / suggestedContribution) * 100 : 0,
          });
        }
      }

      // Sort by joined date (newest first)
      participationHistory.sort((a, b) => (b['joinedAt'] as Timestamp).compareTo(a['joinedAt'] as Timestamp));

      return participationHistory;
    } catch (e) {
      debugPrint('❌ ParticipantService Error: $e');
      return [];
    }
  }

  Future<String> joinProgram(ParticipantModel participant) async {
    try {
      final existingSnapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: participant.programId)
          .where('userId', isEqualTo: participant.userId)
          .get();
      if (existingSnapshot.docs.isNotEmpty) {
        final alreadyJoined = existingSnapshot.docs.any((doc) => doc['status'] == 'joined');
        if (alreadyJoined) {
          throw Exception('You have already joined this program');
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
      throw Exception('Failed to join program: $e');
    }
  }

  Future<void> leaveProgram(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'joined')
          .get();
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
      throw Exception('Failed to leave program: $e');
    }
  }

  Future<String> addParticipant(ParticipantModel participant) async {
    try {
      final existingSnapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: participant.programId)
          .where('userId', isEqualTo: participant.userId)
          .where('status', isEqualTo: 'joined')
          .get();
      if (existingSnapshot.docs.isNotEmpty) {
        throw Exception('User is already a participant in this program');
      }
      final cancelledSnapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: participant.programId)
          .where('userId', isEqualTo: participant.userId)
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

  Future<List<ParticipantModel>> getUserProgramParticipations(String userId, String communityId) async {
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

  Future<List<ParticipantModel>> getProgramParticipants(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .get();
      return snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load program participants: $e');
    }
  }

  Future<bool> hasUserJoinedProgram(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'joined')
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check participation: $e');
    }
  }

  Future<int> getProgramParticipantCount(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get participant count: $e');
    }
  }

  Stream<int> streamProgramParticipantCount(String programId) {
    return _firestore
        .collection('participants')
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<ParticipantModel>> streamUserProgramParticipations(String userId, String communityId) {
    return _firestore
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<ParticipantModel>> streamProgramParticipants(String programId) {
    return _firestore
        .collection('participants')
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList());
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

  Future<ParticipantModel?> getParticipantByProgramAndUser(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
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

  Future<List<ParticipantModel>> getAllUserParticipations(String userId) async {
    try {
      final snapshot = await _firestore.collection('participants').where('userId', isEqualTo: userId).get();
      return snapshot.docs.map((doc) => ParticipantModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load all user participations: $e');
    }
  }

  Future<void> updateParticipantContribution(String userId, String programId) async {
    try {
      final contributionsSnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .get();

      double totalPaid = 0.0;
      for (final doc in contributionsSnapshot.docs) {
        totalPaid += (doc.data()['amount'] ?? 0).toDouble();
      }

      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution =
          programDoc.exists ? (programDoc.data()!['suggestedContribution'] ?? 0).toDouble() : 0.0;

      final participantQuery = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .get();

      if (participantQuery.docs.isNotEmpty) {
        final participantDoc = participantQuery.docs.first;
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