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
    debugPrint('🎯 ParticipantService: Getting participation history for member: $memberId');
    
    // FIRST: Get the user to get their communityId
    final userDoc = await _firestore.collection('users').doc(memberId).get();
    if (!userDoc.exists) {
      debugPrint('❌ ParticipantService: User $memberId not found in users collection');
      return [];
    }
    
    final userData = userDoc.data()!;
    final communityId = userData['communityId'];
    
    if (communityId == null || communityId.isEmpty) {
      debugPrint('⚠️ ParticipantService: User $memberId has no communityId');
      return [];
    }
    
    debugPrint('🏠 ParticipantService: User belongs to community: $communityId');
    
    // Get all participants for this user IN THEIR COMMUNITY
    final participationSnapshot = await _firestore
        .collection('participants')
        .where('userId', isEqualTo: memberId)
        .where('communityId', isEqualTo: communityId) // ✅ ADD THIS FILTER
        .get();
    
    debugPrint('📊 ParticipantService: Found ${participationSnapshot.docs.length} participant documents');
    
    // Debug: Print participant data
    for (final doc in participationSnapshot.docs) {
      debugPrint('   👤 Participant Doc ${doc.id}: ${doc.data()}');
    }
    
    // Get all contributions for this user to calculate totals
    final contributionsSnapshot = await _firestore
        .collection('contributions')
        .where('userId', isEqualTo: memberId)
        .where('communityId', isEqualTo: communityId) // ✅ ADD THIS FILTER
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
    
    final participationHistory = <Map<String, dynamic>>[];
    
    for (final doc in participationSnapshot.docs) {
      final participation = doc.data();
      final programId = participation['programId'] as String?;
      
      if (programId == null || programId.isEmpty) {
        debugPrint('⚠️ ParticipantService: Skipping participant without programId');
        continue;
      }
      
      debugPrint('🔍 ParticipantService: Processing program: $programId');
      
      try {
        final programDoc = await _firestore
            .collection('programs')
            .doc(programId)
            .get();
            
        if (programDoc.exists) {
          final programData = programDoc.data()!;
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
            'communityId': communityId, // ✅ ADD THIS
          });
          
          debugPrint('✅ ParticipantService: Added participation for program: ${programData['title']}');
        } else {
          debugPrint('⚠️ ParticipantService: Program $programId not found');
        }
      } catch (e) {
        debugPrint('❌ ParticipantService Error fetching program $programId: $e');
      }
    }
    
    // Sort by joined date (newest first)
    participationHistory.sort((a, b) => 
        (b['joinedAt'] as Timestamp).compareTo(a['joinedAt'] as Timestamp));
    
    debugPrint('✅ ParticipantService: Returning ${participationHistory.length} participation history items');
    return participationHistory;
  } catch (e) {
    debugPrint('❌❌❌ ParticipantService Error in getMemberParticipationHistory: $e');
    debugPrint('❌❌❌ Stack trace: ${e.toString()}');
    return [];
  }
}
// ✅ ADD THIS: Get participant by programId and userId
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
    return ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  } catch (e) {
    debugPrint('❌ ParticipantService Error in getParticipant: $e');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> getUserParticipationHistoryWithContributions(String userId) async {
  try {
    debugPrint('🎯 ParticipantService.getUserParticipationHistoryWithContributions for: $userId');
    
    // Get user's community first
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      debugPrint('❌ User not found: $userId');
      return []; // ✅ RETURN EMPTY LIST
    }
    
    final userData = userDoc.data()!;
    final communityId = userData['communityId'];
    
    if (communityId == null || communityId.isEmpty) {
      debugPrint('❌ User has no community: $userId');
      return []; // ✅ RETURN EMPTY LIST
    }
    
    // Get all participants for this user
    final participationSnapshot = await _firestore
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId) // ✅ ADD THIS
        .where('status', isEqualTo: 'joined')
        .get();
    
    // Get all contributions for this user to calculate totals
    final contributionsSnapshot = await _firestore
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId) // ✅ ADD THIS
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
    
    final participationHistory = <Map<String, dynamic>>[];
    
    for (final doc in participationSnapshot.docs) {
      final participation = doc.data();
      final programId = participation['programId'] as String?;
      
      if (programId == null || programId.isEmpty) {
        continue;
      }
      
      try {
        final programDoc = await _firestore
            .collection('programs')
            .doc(programId)
            .get();
            
        if (programDoc.exists) {
          final programData = programDoc.data()!;
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
            'hasPaidContribution': hasFullyPaid, // ✅ REAL-TIME
            'contributionPaid': totalPaid, // ✅ REAL-TIME
            'suggestedContribution': suggestedContribution,
            'progressPercentage': suggestedContribution > 0 
                ? (totalPaid / suggestedContribution) * 100 
                : 0,
          });
        }
      } catch (e) {
        debugPrint('❌ ParticipantService Error fetching program: $e');
      }
    }
    
    // Sort by joined date (newest first)
    participationHistory.sort((a, b) => 
        (b['joinedAt'] as Timestamp).compareTo(a['joinedAt'] as Timestamp));
    
    return participationHistory; // ✅ RETURN THE LIST
  } catch (e) {
    debugPrint('❌ ParticipantService Error: $e');
    return []; // ✅ RETURN EMPTY LIST ON ERROR
  }
}

Future<String> joinProgram(ParticipantModel participant) async {
  try {
    // FIRST: Check for ANY existing participant document (any status)
    final existingSnapshot = await _firestore
        .collection('participants')
        .where('programId', isEqualTo: participant.programId)
        .where('userId', isEqualTo: participant.userId)
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      // Check if already joined
      final alreadyJoined = existingSnapshot.docs
          .any((doc) => doc['status'] == 'joined');
      
      if (alreadyJoined) {
        throw Exception('You have already joined this program');
      }

      // Find a cancelled document to reuse
      final cancelledDocs = existingSnapshot.docs
          .where((doc) => doc['status'] == 'cancelled')
          .toList();

      if (cancelledDocs.isNotEmpty) {
        // Reuse the most recent cancelled document
        final docToReuse = cancelledDocs.first;
        
        // Update with new join data but preserve payment info
        final existingData = docToReuse.data();
        final currentContributionPaid = existingData['contributionPaid'] ?? 0.0;
        final currentHasPaid = existingData['hasPaidContribution'] ?? false;
        
        await docToReuse.reference.update({
          'status': 'joined',
          'joinedAt': Timestamp.fromDate(participant.joinedAt),
          'userName': participant.userName,
          'userEmail': participant.userEmail,
          // Preserve payment information!
          'contributionPaid': currentContributionPaid,
          'hasPaidContribution': currentHasPaid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return docToReuse.id;
      }
    }

    // No existing document, create new one
    final docRef = await _firestore.collection('participants').add(participant.toMap());
    return docRef.id;
    
  } catch (e) {
    throw Exception('Failed to join program: $e');
  }
}

  // Leave program
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
      
      // Preserve payment information when leaving
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
// Add this method to your ParticipantService class:

// ✅ Add participant directly (admin function)
Future<String> addParticipant(ParticipantModel participant) async {
  try {
    // Check if participant already exists with status 'joined'
    final existingSnapshot = await _firestore
        .collection('participants')
        .where('programId', isEqualTo: participant.programId)
        .where('userId', isEqualTo: participant.userId)
        .where('status', isEqualTo: 'joined')
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      throw Exception('User is already a participant in this program');
    }

    // Check for cancelled status to reuse
    final cancelledSnapshot = await _firestore
        .collection('participants')
        .where('programId', isEqualTo: participant.programId)
        .where('userId', isEqualTo: participant.userId)
        .where('status', isEqualTo: 'cancelled')
        .get();

    if (cancelledSnapshot.docs.isNotEmpty) {
      // Reuse cancelled document
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

    // Create new participant document
    final docRef = await _firestore.collection('participants').add(participant.toMap());
    return docRef.id;
    
  } catch (e) {
    throw Exception('Failed to add participant: $e');
  }
}
  // Get user's program participations
  Future<List<ParticipantModel>> getUserProgramParticipations(String userId, String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('participants') // Using 'participants' collection
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'joined')
          .get();

      return snapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load participations: $e');
    }
  }

  // Get program participants
  Future<List<ParticipantModel>> getProgramParticipants(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('participants') // Using 'participants' collection
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .get();

      return snapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load program participants: $e');
    }
  }

  // Check if user has joined program
  Future<bool> hasUserJoinedProgram(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('participants') // Using 'participants' collection
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'joined')
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check participation: $e');
    }
  }

  // Get participant count for a program
  Future<int> getProgramParticipantCount(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('participants') // Using 'participants' collection
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get participant count: $e');
    }
  }

  // Stream for real-time participant count
  Stream<int> streamProgramParticipantCount(String programId) {
    return _firestore
        .collection('participants') // Using 'participants' collection
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Stream user program participations for real-time updates
  Stream<List<ParticipantModel>> streamUserProgramParticipations(String userId, String communityId) {
    return _firestore
        .collection('participants') // Using 'participants' collection
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Stream program participants for real-time updates
  Stream<List<ParticipantModel>> streamProgramParticipants(String programId) {
    return _firestore
        .collection('participants') // Using 'participants' collection
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Update participant payment status
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

  // Get participant by ID
  Future<ParticipantModel?> getParticipantById(String participantId) async {
    try {
      final doc = await _firestore.collection('participants').doc(participantId).get();
      if (doc.exists) {
        return ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get participant: $e');
    }
  }

  // Get participant by program and user
  Future<ParticipantModel?> getParticipantByProgramAndUser(String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('participants') // Using 'participants' collection
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'joined')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ParticipantModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>, 
          snapshot.docs.first.id
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get participant: $e');
    }
  }

  // Update participant information
  Future<void> updateParticipant(String participantId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('participants').doc(participantId).update(updates);
    } catch (e) {
      throw Exception('Failed to update participant: $e');
    }
  }

  // ✅ Get all participants for a user (regardless of status)
  Future<List<ParticipantModel>> getAllUserParticipations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load all user participations: $e');
    }
  }

  // ✅ Update participant contribution in real-time when a contribution is made
  Future<void> updateParticipantContribution(String userId, String programId) async {
    try {
      // Get all contributions for this user in this program
      final contributionsSnapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .get();
      
      // Calculate total paid
      double totalPaid = 0.0;
      for (final doc in contributionsSnapshot.docs) {
        totalPaid += (doc.data()['amount'] ?? 0).toDouble();
      }
      
      // Get program suggested amount
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = programDoc.exists 
          ? (programDoc.data()!['suggestedContribution'] ?? 0).toDouble()
          : 0.0;
      
      // Find and update participant document
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

