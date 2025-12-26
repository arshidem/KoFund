import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/contributions/models/contribution_model.dart';

class ContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------
  // 🔹 Create
  // -------------------------------
  Future<String> addContribution(ContributionModel contribution) async {
    try {
      final docRef =
          await _firestore.collection('contributions').add(contribution.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add contribution: $e');
    }
  }

  // -------------------------------
  // 🔹 Read (Program-based)
  // -------------------------------
  Future<List<ContributionModel>> getProgramContributions(
      String programId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
              ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load program contributions: $e');
    }
  }

  // 🔹 Read (User-based for specific program)
  Future<List<ContributionModel>> getUserProgramContributions(
      String programId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
              ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load user contributions: $e');
    }
  }

  // 🔹 Read (User-based for entire community)
  Future<List<ContributionModel>> getUserContributions(
      String userId, String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
              ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load user contributions: $e');
    }
  }
Future<List<Map<String, dynamic>>> getMemberContributionHistory(String memberId) async {
  try {
    print('💰 ContributionService: Getting contribution history for member: $memberId');
    
    // FIRST: Get the user to get their communityId
    final userDoc = await _firestore.collection('users').doc(memberId).get();
    if (!userDoc.exists) {
      print('❌ ContributionService: User $memberId not found in users collection');
      return [];
    }
    
    final userData = userDoc.data()!;
    final communityId = userData['communityId'];
    
    if (communityId == null || communityId.isEmpty) {
      print('⚠️ ContributionService: User $memberId has no communityId');
      return [];
    }
    
    print('🏠 ContributionService: User belongs to community: $communityId');
    
    // Get all contributions for this user IN THEIR COMMUNITY
    final contributionSnapshot = await _firestore
        .collection('contributions')
        .where('userId', isEqualTo: memberId)
        .where('communityId', isEqualTo: communityId) // ✅ ADD THIS FILTER
        .orderBy('createdAt', descending: true)
        .get();
    
    print('📊 ContributionService: Found ${contributionSnapshot.docs.length} contribution documents');
    
    // Debug: Print contribution data
    for (final doc in contributionSnapshot.docs) {
      print('   💰 Contribution Doc ${doc.id}: ${doc.data()}');
    }
    
    final contributionHistory = <Map<String, dynamic>>[];
    
    for (final doc in contributionSnapshot.docs) {
      final contribution = doc.data();
      final programId = contribution['programId'] as String?;
      
      if (programId == null || programId.isEmpty) {
        print('⚠️ ContributionService: Skipping contribution without programId');
        continue;
      }
      
      print('🔍 ContributionService: Processing program: $programId');
      
      try {
        final programDoc = await _firestore
            .collection('programs')
            .doc(programId)
            .get();
            
        if (programDoc.exists) {
          final programData = programDoc.data()!;
          
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
            'communityId': communityId, // ✅ ADD THIS
          });
          
          print('✅ ContributionService: Added contribution for program: ${programData['title']}');
        } else {
          print('⚠️ ContributionService: Program $programId not found');
          
          // Still add contribution with basic info
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
      } catch (e) {
        print('❌ ContributionService Error fetching program $programId: $e');
      }
    }
    
    print('✅ ContributionService: Returning ${contributionHistory.length} contribution history items');
    return contributionHistory;
  } catch (e) {
    print('❌❌❌ ContributionService Error in getMemberContributionHistory: $e');
    print('❌❌❌ Stack trace: ${e.toString()}');
    return [];
  }
}
  // 🔹 Read (Admin - all contributions in a community)
  Future<List<ContributionModel>> getCommunityContributions(String communityId) async {
    print('🔄 SERVICE: Starting getCommunityContributions for community: $communityId');
    try {
      print('🔥 SERVICE: Executing Firestore query...');
      
      final snapshot = await _firestore
          .collection('contributions')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();

      print('✅ SERVICE: Query successful, found ${snapshot.docs.length} documents');
      
      final contributions = snapshot.docs
          .map((doc) {
            print('📄 SERVICE: Processing doc ${doc.id} - data: ${doc.data()}');
            return ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          })
          .toList();
      
      print('🎯 SERVICE: Successfully parsed ${contributions.length} contributions');
      return contributions;
      
    } catch (e) {
      print('❌ SERVICE ERROR: Failed to load community contributions: $e');
      throw Exception('Failed to load community contributions: $e');
    }
  }
// In your ContributionService class
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
    print('❌ ContributionService Error: $e');
    return [];
  }
}
  // -------------------------------
  // 🔹 Calculations (SIMPLIFIED - NO STATUS CHECKS)
  // -------------------------------
  Future<double> getProgramTotalContributions(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate total contributions: $e');
    }
  }

  Future<double> getUserProgramTotalContributions(
      String programId, String userId) async {
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

  // ✅ FIXED: Get actual program amount from Firestore
  Future<Map<String, dynamic>> getUserPaymentProgress(
      String programId, String userId) async {
    try {
      final totalPaid = await getUserProgramTotalContributions(programId, userId);
      
      // Get actual program suggested amount from Firestore
      final programDoc = await _firestore
          .collection('programs')
          .doc(programId)
          .get();
      
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

  Future<double> getUserTotalContributions(
      String userId, String communityId) async {
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
  // 🔹 Enhanced Analytics Methods (SIMPLIFIED)
  // -------------------------------

  // ✅ Get program payment summary with participant breakdown
  Future<Map<String, dynamic>> getProgramPaymentSummary(String programId) async {
    try {
      final contributions = await getProgramContributions(programId);
      
      // Get program details
      final programDoc = await _firestore
          .collection('programs')
          .doc(programId)
          .get();
      
      if (!programDoc.exists) {
        throw Exception('Program not found');
      }
      
      final programData = programDoc.data()!;
      final suggestedAmount = (programData['suggestedContribution'] ?? 0).toDouble();
      final currentParticipants = (programData['currentParticipants'] ?? 0) as int;
      
      // Calculate totals (ALL CONTRIBUTIONS ARE COMPLETED)
      double totalCollected = 0;
      final Map<String, double> userTotals = {};
      int fullyPaidUsers = 0;
      int partiallyPaidUsers = 0;
      int notPaidUsers = 0;
      
      for (final contribution in contributions) {
        totalCollected += contribution.amount;
        userTotals[contribution.userId] = 
            (userTotals[contribution.userId] ?? 0) + contribution.amount;
      }
      
      // Analyze payment status for each user
      userTotals.forEach((userId, totalPaid) {
        if (totalPaid >= suggestedAmount) {
          fullyPaidUsers++;
        } else if (totalPaid > 0) {
          partiallyPaidUsers++;
        }
      });
      
      notPaidUsers = currentParticipants - (fullyPaidUsers + partiallyPaidUsers);
      
      return {
        'totalCollected': totalCollected,
        'expectedAmount': suggestedAmount * currentParticipants,
        'suggestedAmount': suggestedAmount,
        'fullyPaidUsers': fullyPaidUsers,
        'partiallyPaidUsers': partiallyPaidUsers,
        'notPaidUsers': notPaidUsers,
        'totalParticipants': currentParticipants,
        'collectionProgress': suggestedAmount > 0 ? (totalCollected / (suggestedAmount * currentParticipants)) * 100 : 0,
        'userPaymentBreakdown': userTotals,
      };
    } catch (e) {
      throw Exception('Failed to get program payment summary: $e');
    }
  }

  // ✅ Get top contributors in community
  Future<List<Map<String, dynamic>>> getTopContributors(String communityId, {int limit = 10}) async {
    try {
      final contributions = await getCommunityContributions(communityId);
      
      final Map<String, double> userTotals = {};
      
      // Calculate totals (ALL CONTRIBUTIONS ARE COMPLETED)
      for (final contribution in contributions) {
        userTotals[contribution.userId] = 
            (userTotals[contribution.userId] ?? 0) + contribution.amount;
      }
      
      // Convert to list and sort
      final contributorList = userTotals.entries.map((entry) => {
        'userId': entry.key,
        'totalAmount': entry.value,
        'contributionCount': contributions.where((c) => c.userId == entry.key).length,
      }).toList();
      
      // ✅ Sort by total amount descending with proper type casting
      contributorList.sort((a, b) {
        final amountA = a['totalAmount'] as double;
        final amountB = b['totalAmount'] as double;
        return amountB.compareTo(amountA);
      });
      
      return contributorList.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get top contributors: $e');
    }
  }

  // ✅ Get payment statistics for dashboard
  Future<Map<String, dynamic>> getCommunityPaymentStats(String communityId) async {
    try {
      final contributions = await getCommunityContributions(communityId);
      
      double totalAmount = 0;
      final Map<String, double> paymentMethodTotals = {};
      final Map<String, int> dailyContributions = {};
      
      for (final contribution in contributions) {
        totalAmount += contribution.amount;
        
        // Payment method breakdown
        paymentMethodTotals[contribution.paymentMethod] = 
            (paymentMethodTotals[contribution.paymentMethod] ?? 0) + contribution.amount;
        
        // Daily breakdown (format: YYYY-MM-DD)
        final dateKey = _formatDate(contribution.createdAt.toDate());
        dailyContributions[dateKey] = (dailyContributions[dateKey] ?? 0) + 1;
      }
      
      return {
        'totalContributions': contributions.length,
        'totalAmount': totalAmount,
        'averageContribution': contributions.isNotEmpty ? 
            totalAmount / contributions.length : 0,
        'paymentMethodBreakdown': paymentMethodTotals,
        'dailyActivity': dailyContributions,
        'lastUpdated': Timestamp.now(),
      };
    } catch (e) {
      throw Exception('Failed to get payment statistics: $e');
    }
  }

  // ✅ ADDED: Get user payment history with program details
  Future<List<Map<String, dynamic>>> getUserPaymentHistoryWithDetails(
      String userId, String communityId) async {
    try {
      // Get user's contributions
      final userContributions = await getUserContributions(userId, communityId);
      
      // Get program details for each contribution
      final List<Map<String, dynamic>> paymentHistory = [];
      
      for (final contribution in userContributions) {
        try {
          // Get program details
          final programDoc = await _firestore
              .collection('programs')
              .doc(contribution.programId)
              .get();
          
          if (programDoc.exists) {
            final programData = programDoc.data()!;
            
            paymentHistory.add({
              'contributionId': contribution.contributionId,
              'programId': contribution.programId,
              'programTitle': programData['title'] ?? 'Unknown Program',
              'programDate': programData['programDate'],
              'amount': contribution.amount,
              'paymentMethod': contribution.paymentMethod,
              'status': contribution.status,
              'createdAt': contribution.createdAt,
              'programType': programData['programType'] ?? 'general',
              'suggestedContribution': (programData['suggestedContribution'] ?? 0).toDouble(),
            });
          } else {
            // Program not found, but still include contribution
            paymentHistory.add({
              'contributionId': contribution.contributionId,
              'programId': contribution.programId,
              'programTitle': 'Program Not Found',
              'programDate': null,
              'amount': contribution.amount,
              'paymentMethod': contribution.paymentMethod,
              'status': contribution.status,
              'createdAt': contribution.createdAt,
              'programType': 'unknown',
              'suggestedContribution': 0,
            });
          }
        } catch (e) {
          // If there's an error fetching program details, still include the contribution
          paymentHistory.add({
            'contributionId': contribution.contributionId,
            'programId': contribution.programId,
            'programTitle': 'Deleted Program',
            'programDate': null,
            'amount': contribution.amount,
            'paymentMethod': contribution.paymentMethod,
            'status': contribution.status,
            'createdAt': contribution.createdAt,
            'programType': 'error',
            'suggestedContribution': 0,
          });
        }
      }
      
      // Sort by creation date (newest first)
      paymentHistory.sort((a, b) {
        final Timestamp timestampA = a['createdAt'];
        final Timestamp timestampB = b['createdAt'];
        return timestampB.compareTo(timestampA);
      });
      
      return paymentHistory;
    } catch (e) {
      throw Exception('Failed to get user payment history with details: $e');
    }
  }

  // ✅ REMOVED: bulkMarkPayments (not needed since all are completed)

  // ✅ Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // -------------------------------
  // 🔹 Update / Delete
  // -------------------------------

Future<void> updateContribution(ContributionModel contribution, {
  required String editedByUserId,
  required String editedByUserName,
  String? editReason,
}) async {
  try {
    // Get document reference from root 'contributions' collection
    final docRef = _firestore
        .collection('contributions')
        .doc(contribution.contributionId);
    
    final snapshot = await docRef.get();
    
    // Throw error if document not found
    if (!snapshot.exists) {
      throw Exception('Contribution document not found');
    }
    
    final currentData = snapshot.data();
    
    if (currentData == null || currentData is! Map<String, dynamic>) {
      throw Exception('Document has no data');
    }
    
    final currentContribution = ContributionModel.fromMap(currentData, snapshot.id);
    
    // Helper function to get program title
    Future<Map<String, String>> _getProgramInfo(String programId, String? communityId) async {
      try {
        String? programTitle;
        String? programLocation;
        
        // Try to get program details from multiple possible locations
        
        // 1. Try from 'programs' root collection
        final programDoc = await _firestore
            .collection('programs')
            .doc(programId)
            .get();
            
        if (programDoc.exists && programDoc.data() != null) {
          final data = programDoc.data()!;
          programTitle = data['title'] as String? ?? 'Program $programId';
          programLocation = data['location'] as String? ?? '';
        }
        
        // 2. If not found, try from community's programs subcollection
        if (programTitle == null && communityId != null && communityId.isNotEmpty) {
          final subProgramDoc = await _firestore
              .collection('communities')
              .doc(communityId)
              .collection('programs')
              .doc(programId)
              .get();
              
          if (subProgramDoc.exists && subProgramDoc.data() != null) {
            final data = subProgramDoc.data()!;
            programTitle = data['title'] as String? ?? 'Program $programId';
            programLocation = data['location'] as String? ?? '';
          }
        }
        
        // 3. Fallback if still not found
        if (programTitle == null) {
          programTitle = 'Program $programId';
        }
        
        return {
          'title': programTitle,
          'location': programLocation ?? '',
          'id': programId,
        };
        
      } catch (e) {
        print('⚠️ Error fetching program info: $e');
        return {
          'title': 'Program $programId',
          'location': '',
          'id': programId,
        };
      }
    }
    
    // Detect changes
    final Map<String, Map<String, dynamic>> changes = {};
    
    if (currentContribution.amount != contribution.amount) {
      changes['amount'] = {
        'old': currentContribution.amount,
        'new': contribution.amount,
      };
    }
    
    if (currentContribution.paymentMethod != contribution.paymentMethod) {
      changes['paymentMethod'] = {
        'old': currentContribution.paymentMethod,
        'new': contribution.paymentMethod,
      };
    }
    
    // PROGRAM CHANGE: Store titles instead of IDs
    if (currentContribution.programId != contribution.programId) {
      // Get program info for both old and new
      final oldProgramInfo = await _getProgramInfo(
        currentContribution.programId, 
        currentContribution.communityId
      );
      final newProgramInfo = await _getProgramInfo(
        contribution.programId, 
        contribution.communityId
      );
      
      changes['program'] = { // Changed key from 'programId' to 'program'
        'old': oldProgramInfo['title'],
        'new': newProgramInfo['title'],
        // Include additional info if needed
        'oldId': currentContribution.programId,
        'newId': contribution.programId,
        'oldLocation': oldProgramInfo['location'],
        'newLocation': newProgramInfo['location'],
      };
    }
    
    if (currentContribution.userId != contribution.userId) {
      changes['userId'] = {
        'old': currentContribution.userId,
        'new': contribution.userId,
      };
    }
    
    if (currentContribution.note != contribution.note) {
      changes['note'] = {
        'old': currentContribution.note ?? '',
        'new': contribution.note ?? '',
      };
    }
    
    if (currentContribution.isMonthlyContribution != contribution.isMonthlyContribution) {
      changes['isMonthlyContribution'] = {
        'old': currentContribution.isMonthlyContribution,
        'new': contribution.isMonthlyContribution,
      };
    }
    
    if (currentContribution.monthId != contribution.monthId) {
      changes['monthId'] = {
        'old': currentContribution.monthId ?? '',
        'new': contribution.monthId ?? '',
      };
    }
    
    // ✅ FIX: Only add edit history if there are actual changes
    if (changes.isNotEmpty) {
      // Get existing edit history
      List<dynamic> existingHistory = [];
      final historyData = currentData['editHistory'];
      if (historyData is List) {
        existingHistory = List<dynamic>.from(historyData);
      }
      
      // Add new edit record only if there are changes
      final editRecord = {
        'editedAt': Timestamp.now(),
        'editedByUserId': editedByUserId,
        'editedByUserName': editedByUserName,
        'changes': changes,
        'reason': editReason ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final updatedHistory = List<dynamic>.from(existingHistory)..add(editRecord);
      
      // Prepare update data - STORE PROGRAM ID IN MAIN DOCUMENT
      final updateData = {
        'amount': contribution.amount,
        'paymentMethod': contribution.paymentMethod,
        'programId': contribution.programId, // Store ID here
        'userId': contribution.userId,
        'note': contribution.note,
        'isMonthlyContribution': contribution.isMonthlyContribution,
        'monthId': contribution.monthId,
        
        // Edit tracking
        'isEdited': true,
        'lastEditedByUserId': editedByUserId,
        'lastEditedByUserName': editedByUserName,
        'lastEditedAt': Timestamp.now(),
        'editReason': editReason,
        'editHistory': updatedHistory,
        'updatedAt': Timestamp.now(),
      };
      
      // Remove null values
      final cleanUpdateData = Map<String, dynamic>.from(updateData)
        ..removeWhere((key, value) => value == null);
      
      await docRef.update(cleanUpdateData);
    } else {
      // If no changes, just update the timestamp
      await docRef.update({
        'updatedAt': Timestamp.now(),
      });
    }
    
  } catch (e) {
    throw Exception('Failed to update contribution: $e');
  }
}

  // ✅ REMOVED: updateContributionStatus (not needed since all are completed)

  Future<void> deleteContribution(String contributionId) async {
    try {
      await _firestore.collection('contributions').doc(contributionId).delete();
    } catch (e) {
      throw Exception('Failed to delete contribution: $e');
    }
  }

  // -------------------------------
  // 🔹 Real-time Streams (SIMPLIFIED)
  // -------------------------------
  Stream<List<ContributionModel>> streamProgramContributions(String programId) {
    return _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<ContributionModel>> streamUserContributions(
      String userId, String communityId) {
    return _firestore
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<ContributionModel>> streamCommunityContributions(
      String communityId) {
    return _firestore
        .collection('contributions')
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<double> streamProgramTotalContributions(String programId) {
    return _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    });
  }
  // Add these methods to your ContributionService class in contribution_service.dart

// 🔹 Get monthly contributions for a specific program-month
Future<List<ContributionModel>> getMonthlyContributionsForProgram(
  String programId, 
  String monthId
) async {
  try {
    final snapshot = await _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
        .where('monthId', isEqualTo: monthId)
        .where('isMonthlyContribution', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => 
            ContributionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  } catch (e) {
    print('❌ Error getting monthly contributions: $e');
    return [];
  }
}

// 🔹 Check if user paid for specific month
Future<bool> hasUserPaidForMonth(
  String userId, 
  String programId, 
  String monthId
) async {
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
    print('❌ Error checking monthly payment: $e');
    return false;
  }
}

// 🔹 Get all monthly contributions for a program (grouped by month)
Future<Map<String, List<ContributionModel>>> getMonthlyContributionsByMonth(
  String programId
) async {
  try {
    final snapshot = await _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
        .where('isMonthlyContribution', isEqualTo: true)
        .orderBy('monthId', descending: true)
        .get();

    // Group by monthId
    final Map<String, List<ContributionModel>> monthlyMap = {};
    
    for (final doc in snapshot.docs) {
      final contribution = ContributionModel.fromMap(
        doc.data() as Map<String, dynamic>, 
        doc.id
      );
      final monthId = contribution.monthId ?? 'unknown';
      
      if (!monthlyMap.containsKey(monthId)) {
        monthlyMap[monthId] = [];
      }
      monthlyMap[monthId]!.add(contribution);
    }
    
    return monthlyMap;
  } catch (e) {
    print('❌ Error getting monthly contributions by month: $e');
    return {};
  }
}

// 🔹 Get monthly payment status for all participants
Future<Map<String, bool>> getMonthlyPaymentStatus(
  String programId, 
  String monthId
) async {
  try {
    final snapshot = await _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
        .where('monthId', isEqualTo: monthId)
        .where('isMonthlyContribution', isEqualTo: true)
        .get();

    final Map<String, bool> paymentStatus = {};
    
    for (final doc in snapshot.docs) {
      final contribution = doc.data();
      final userId = contribution['userId'] as String;
      paymentStatus[userId] = true;
    }
    
    return paymentStatus;
  } catch (e) {
    print('❌ Error getting monthly payment status: $e');
    return {};
  }
}
}