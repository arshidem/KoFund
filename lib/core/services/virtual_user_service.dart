import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;
import '../../../features/auth/models/user_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class VirtualUserCreationResult {
  final List<UserModel> createdUsers;
  final List<Map<String, dynamic>> failedUsers; // Each map has name, phone, email, and error

  VirtualUserCreationResult({
    required this.createdUsers,
    required this.failedUsers,
  });
}

class VirtualUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();
  
  // Cache for frequently accessed data
  final Map<String, List<UserModel>> _virtualUsersCache = {};
  final Map<String, int> _userCountCache = {};

  // Create single virtual user with transaction for data consistency
Future<UserModel> createVirtualUser({
  required String communityId,
  required String displayName,
  required String adminUid,
  required String adminName, // Add this parnameter
  String? phoneNumber,
  String? email,
}) async {
  developer.log('Creating virtual user: $displayName for community: $communityId');

  try {
    // Validate inputs
    _validateUserInputs(
      displayName: displayName,
      phoneNumber: phoneNumber,
      email: email,
    );

    return await _firestore.runTransaction((transaction) async {
      final virtualUserId = 'virtual_${_uuid.v4()}';
      final sanitizedName = _sanitizeNnameForEmail(displayName);
      final virtualEmail = email ?? '$sanitizedName@virtual.kofund.app';

      // Check for duplicates in this community
      final existingMembers = await _getExistingCommunityMembers(communityId);
      for (final existing in existingMembers) {
        final existingName = existing['displayName'] as String;
        final existingPhone = existing['phoneNumber'] as String;
        final existingEmail = existing['email'] as String;
        
        if (existingName.toLowerCase() == displayName.trim().toLowerCase()) {
          throw Exception('Member with name "$displayName" already exists in this community. Please use a different name or add initials (e.g. "$displayName A").');
        }
        if (phoneNumber != null && phoneNumber.isNotEmpty && existingPhone == phoneNumber.trim()) {
          throw Exception('Member "$displayName" has phone "$phoneNumber" which already exists in this community. Please use a different phone number.');
        }
        if (email != null && email.isNotEmpty && existingEmail.toLowerCase() == email.trim().toLowerCase()) {
          throw Exception('Member "$displayName" has email "$email" which already exists in this community. Please use a different email.');
        }
      }

      final virtualUser = UserModel(
        uid: virtualUserId,
        email: virtualEmail,
        displayName: displayName.trim(),
        phoneNumber: phoneNumber?.trim(),
        communityId: communityId,
        communityName: null,
        role: 'member',
        isApproved: true,
        isAdmin: false,
        isDeveloper: false,
        isVirtualUser: true,
        createdBy: adminUid,
        createdByName: adminName.trim(), // Add admin name here
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        showDetailedProfile: false,
      );

      // Save to users collection
      transaction.set(
        _firestore.collection('users').doc(virtualUserId),
        virtualUser.toMap(),
      );

      // Add to community's virtual users subcollection
      transaction.set(
        _firestore
            .collection('communities')
            .doc(communityId)
            .collection('virtualUsers')
            .doc(virtualUserId),
        {
          'uid': virtualUserId,
          'displayName': displayName.trim(),
          'phoneNumber': phoneNumber?.trim(),
          'email': virtualEmail,
          'createdBy': adminUid,
          'createdByName': adminName.trim(), // Add here too
          'createdAt': Timestamp.now(),
          'isActive': true,
          'status': 'active',
          'updatedAt': Timestamp.now(),
        },
      );

      // Clear cache for this community
      _clearCacheForCommunity(communityId);

      developer.log('Successfully created virtual user: $virtualUserId');
      return virtualUser;
    });
  } catch (e, stackTrace) {
    developer.log('Failed to create virtual user: $e', 
                  error: e, 
                  stackTrace: stackTrace);
    rethrow;
  }
}

  // Create multiple virtual users with batch operation
  Future<VirtualUserCreationResult> createMultipleVirtualUsers({
    required String communityId,
    required String adminUid,
    required String adminName, // Add this parnameter
    required List<Map<String, dynamic>> usersData,
  }) async {
    developer.log('Creating ${usersData.length} virtual users for community: $communityId');

    final createdUsers = <UserModel>[];
    final failedUsers = <Map<String, dynamic>>[];

    try {
      // Check for duplicates before starting batch against all members in this community
      final existingMembers = await _getExistingCommunityMembers(communityId);
      final batch = _firestore.batch();
      bool hasBatchData = false;

      for (final userData in usersData) {
        final name = (userData['name'] as String? ?? '').trim();
        final phone = userData['phone'] as String?;
        final email = userData['email'] as String?;

        if (name.isEmpty) {
          failedUsers.add({
            'name': name,
            'phone': phone,
            'email': email,
            'error': 'Display name cannot be empty',
          });
          continue;
        }

        String? duplicateError;
        for (final existing in existingMembers) {
          final existingName = existing['displayName'] as String;
          final existingPhone = existing['phoneNumber'] as String;
          final existingEmail = existing['email'] as String;

          if (existingName.toLowerCase() == name.toLowerCase()) {
            duplicateError = 'Member with name "$name" already exists in this community. Please use a different name or add initials (e.g. "$name A").';
            break;
          }
          if (phone != null && phone.isNotEmpty && existingPhone == phone) {
            duplicateError = 'Member "$name" has phone "$phone" which already exists in this community. Please use a different phone number.';
            break;
          }
          if (email != null && email.isNotEmpty && existingEmail.toLowerCase() == email.toLowerCase()) {
            duplicateError = 'Member "$name" has email "$email" which already exists in this community. Please use a different email.';
            break;
          }
        }

        if (duplicateError != null) {
          failedUsers.add({
            'name': name,
            'phone': phone,
            'email': email,
            'error': duplicateError,
          });
          continue;
        }

        // Validate user inputs
        try {
          _validateUserInputs(
            displayName: name,
            phoneNumber: phone,
            email: email,
          );
        } catch (e) {
          failedUsers.add({
            'name': name,
            'phone': phone,
            'email': email,
            'error': e.toString(),
          });
          continue;
        }

        // Add valid user to batch
        final virtualUserId = 'virtual_${_uuid.v4()}';
        final sanitizedName = _sanitizeNnameForEmail(name);
        final virtualEmail = email ?? '$sanitizedName@virtual.kofund.app';

        final virtualUser = UserModel(
          uid: virtualUserId,
          email: virtualEmail,
          displayName: name,
          phoneNumber: phone?.trim(),
          communityId: communityId,
          communityName: null,
          role: 'member',
          isApproved: true,
          isAdmin: false,
          isDeveloper: false,
          isVirtualUser: true,
          createdBy: adminUid,
          createdByName: adminName.trim(),
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          showDetailedProfile: false,
        );

        final userRef = _firestore.collection('users').doc(virtualUserId);
        batch.set(userRef, virtualUser.toMap());

        final communityUserRef = _firestore
            .collection('communities')
            .doc(communityId)
            .collection('virtualUsers')
            .doc(virtualUserId);
        
        batch.set(communityUserRef, {
          'uid': virtualUserId,
          'displayName': name,
          'phoneNumber': phone?.trim(),
          'email': virtualEmail,
          'createdBy': adminUid,
          'createdByName': adminName.trim(),
          'createdAt': Timestamp.now(),
          'isActive': true,
          'status': 'active',
          'updatedAt': Timestamp.now(),
        });

        createdUsers.add(virtualUser);
        hasBatchData = true;
      }

      if (hasBatchData) {
        await batch.commit();
        _clearCacheForCommunity(communityId);
      }

      developer.log('Batch creation finished: ${createdUsers.length} succeeded, ${failedUsers.length} failed.');
      return VirtualUserCreationResult(
        createdUsers: createdUsers,
        failedUsers: failedUsers,
      );
    } catch (e, stackTrace) {
      developer.log('Failed to create multiple virtual users: $e', 
                    error: e, 
                    stackTrace: stackTrace);
      rethrow;
    }
  }
  Future<void> updateVirtualUser({
    required String userId,
    required String displayName,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      // First, check if it's actually a virtual user
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data();
      if (userData?['isVirtualUser'] != true) {
        throw Exception('Only virtual users can be updated through this service');
      }

      // Prepare update data
      final updateData = {
        'displayName': displayName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add optional fields if provided
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        updateData['phoneNumber'] = phoneNumber.trim();
      }
      
      if (email != null && email.isNotEmpty) {
        updateData['email'] = email.trim();
      }
      
      // Update in users collection
      await _firestore.collection('users').doc(userId).update(updateData);
      
      // Also update in virtual_users collection if it exists
      final virtualUserRef = _firestore.collection('virtual_users').doc(userId);
      final virtualUserDoc = await virtualUserRef.get();
      
      if (virtualUserDoc.exists) {
        await virtualUserRef.update(updateData);
      }
      
      debugPrint('✅ DEBUG: Virtual user $userId updated successfully');
    } catch (e) {
      debugPrint('❌ DEBUG: Error updating virtual user: $e');
      throw Exception('Failed to update virtual user: $e');
    }
  }
  // Get all virtual users in a community (with optional caching)
  Stream<List<UserModel>> getVirtualUsersStream(String communityId) {
    return _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('isVirtualUser', isEqualTo: true)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
          
          // Update cache
          _virtualUsersCache[communityId] = users;
          return users;
        });
  }

  // Get virtual users with caching
  Future<List<UserModel>> getVirtualUsers(String communityId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _virtualUsersCache.containsKey(communityId)) {
      return _virtualUsersCache[communityId]!;
    }

    final snapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('isVirtualUser', isEqualTo: true)
        .orderBy('displayName')
        .get();

    final users = snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .toList();
    
    _virtualUsersCache[communityId] = users;
    return users;
  }

  // Get virtual user count stream
  Stream<int> getVirtualUserCountStream(String communityId) {
    return _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('isVirtualUser', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final count = snapshot.docs.length;
          _userCountCache[communityId] = count;
          return count;
        });
  }

  // Get virtual user count with caching
  Future<int> getVirtualUserCount(String communityId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _userCountCache.containsKey(communityId)) {
      return _userCountCache[communityId]!;
    }

    final snapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('isVirtualUser', isEqualTo: true)
        .count()
        .get();

    final count = snapshot.count ?? 0;
    _userCountCache[communityId] = count;
    return count;
  }


  // Helper: Erase all related contributions, participants, deleted contributions, and expenses
  Future<void> _deleteVirtualUserData(String userId, String? communityId) async {
    try {
      final List<QuerySnapshot> snapshotsToClean = [];

      // Get all contributions
      var contributionsQuery = _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId);
      if (communityId != null) {
        contributionsQuery = contributionsQuery.where('communityId', isEqualTo: communityId);
      }
      snapshotsToClean.add(await contributionsQuery.get());

      // Get all participants
      var participantsQuery = _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId);
      if (communityId != null) {
        participantsQuery = participantsQuery.where('communityId', isEqualTo: communityId);
      }
      snapshotsToClean.add(await participantsQuery.get());

      // Get all deleted_contributions
      var deletedContribQuery = _firestore
          .collection('deleted_contributions')
          .where('userId', isEqualTo: userId);
      if (communityId != null) {
        deletedContribQuery = deletedContribQuery.where('communityId', isEqualTo: communityId);
      }
      snapshotsToClean.add(await deletedContribQuery.get());

      // Get all expenses
      var expensesQuery = _firestore
          .collection('expenses')
          .where('paidBy', isEqualTo: userId);
      if (communityId != null) {
        expensesQuery = expensesQuery.where('communityId', isEqualTo: communityId);
      }
      snapshotsToClean.add(await expensesQuery.get());

      final batch = _firestore.batch();
      int operationCount = 0;

      for (final snapshot in snapshotsToClean) {
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
          operationCount++;
          if (operationCount >= 400) {
            await batch.commit();
            operationCount = 0;
          }
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
      developer.log('🧹 Cleaned up associated data for virtual user $userId');
    } catch (e) {
      developer.log('Error deleting virtual user related data: $e');
    }
  }

  // Delete virtual user
  Future<void> deleteVirtualUser(String userId) async {
    developer.log('Deleting virtual user: $userId');

    try {
      // 1. Fetch community ID first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final communityId = userData['communityId'] as String?;

      if (communityId == null) {
        throw Exception('Community ID not found for user');
      }

      // 2. Erase all related contributions, participants, expenses, etc.
      await _deleteVirtualUserData(userId, communityId);

      // 3. Delete virtual user documents
      await _firestore.runTransaction((transaction) async {
        // First, delete from users collection
        transaction.delete(_firestore.collection('users').doc(userId));

        // Then delete from community subcollection
        transaction.delete(
          _firestore
              .collection('communities')
              .doc(communityId)
              .collection('virtualUsers')
              .doc(userId),
        );

        // Clear cache for this community
        _clearCacheForCommunity(communityId);
      });

      developer.log('Successfully deleted virtual user: $userId');
    } catch (e, stackTrace) {
      developer.log('Failed to delete virtual user: $e', 
                    error: e, 
                    stackTrace: stackTrace);
      rethrow;
    }
  }

  // Delete multiple virtual users
  Future<void> deleteMultipleVirtualUsers(List<String> userIds) async {
    developer.log('Deleting ${userIds.length} virtual users');

    try {
      if (userIds.isEmpty) return;

      final Set<String> communityIds = {};

      // First, get all users to find their community IDs and erase their related data
      for (final userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final communityId = userDoc.data()?['communityId'] as String?;
          if (communityId != null) {
            communityIds.add(communityId);
            
            // Erase related contributions, participants, etc.
            await _deleteVirtualUserData(userId, communityId);
          }
        }
      }

      final batch = _firestore.batch();
      for (final userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final communityId = userDoc.data()?['communityId'] as String?;
          if (communityId != null) {
            // Delete from users collection
            batch.delete(_firestore.collection('users').doc(userId));

            // Delete from community subcollection
            final communityUserRef = _firestore
                .collection('communities')
                .doc(communityId)
                .collection('virtualUsers')
                .doc(userId);
            batch.delete(communityUserRef);
          }
        }
      }

      await batch.commit();
      
      // Clear cache for affected communities
      for (final communityId in communityIds) {
        _clearCacheForCommunity(communityId);
      }

      developer.log('Successfully deleted multiple virtual users');
    } catch (e, stackTrace) {
      developer.log('Failed to delete multiple virtual users: $e', 
                    error: e, 
                    stackTrace: stackTrace);
      rethrow;
    }
  }

  // Search virtual users with improved search logic
  Future<List<UserModel>> searchVirtualUsers({
    required String communityId,
    required String query,
  }) async {
    if (query.trim().isEmpty) {
      // Return all virtual users if query is empty
      return await getVirtualUsers(communityId);
    }

    final lowerQuery = query.toLowerCase().trim();
    
    final users = await getVirtualUsers(communityId);
    
    return users.where((user) {
      final nameMatch = user.displayName?.toLowerCase().contains(lowerQuery) == true;
      final phoneMatch = user.phoneNumber?.toLowerCase().contains(lowerQuery) == true;
      final emailMatch = user.email.toLowerCase().contains(lowerQuery) == true;
      
      // Also check for partial matches (first name, last name)
      final displayName = user.displayName ?? '';
      final nameParts = displayName.toLowerCase().split(' ');
      final partialMatch = nameParts.any((part) => part.startsWith(lowerQuery));
      
      return nameMatch || phoneMatch || emailMatch || partialMatch;
    }).toList();
  }

  // Check if user with same name already exists in community
  Future<bool> checkDuplicateUser({
    required String communityId,
    required String displayName,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('displayName', isEqualTo: displayName.trim())
        .where('isVirtualUser', isEqualTo: true)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }

  // Get virtual user by ID
  Future<UserModel?> getVirtualUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data()?['isVirtualUser'] == true) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      developer.log('Error getting virtual user by ID: $e');
      return null;
    }
  }

  // Validate phone number format
  bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    return phoneRegex.hasMatch(phone);
  }

  // Validate email format
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Clear all cache
  void clearAllCache() {
    _virtualUsersCache.clear();
    _userCountCache.clear();
    developer.log('Cleared all virtual user cache');
  }

  // Private helper methods

  void _validateUserInputs({
    required String displayName,
    String? phoneNumber,
    String? email,
  }) {
    final trimmedName = displayName.trim();
    
    if (trimmedName.isEmpty) {
      throw ArgumentError('Display name cannot be empty');
    }
    
    if (trimmedName.length < 2) {
      throw ArgumentError('Display name must be at least 2 characters');
    }
    
    if (trimmedName.length > 100) {
      throw ArgumentError('Display name cannot exceed 100 characters');
    }
    
    if (phoneNumber != null && phoneNumber.isNotEmpty && !isValidPhoneNumber(phoneNumber)) {
      throw ArgumentError('Invalid phone number format. Use format: +1234567890');
    }
    
    if (email != null && email.isNotEmpty && !isValidEmail(email)) {
      throw ArgumentError('Invalid email format');
    }
  }

  String _sanitizeNnameForEmail(String name) {
    return name
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase()
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void _clearCacheForCommunity(String communityId) {
    _virtualUsersCache.remove(communityId);
    _userCountCache.remove(communityId);
  }

  Future<Set<String>> _getExistingVirtualUserNnames(String communityId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('isVirtualUser', isEqualTo: true)
        .get();
    
    return snapshot.docs
        .map((doc) => (doc.data()['displayName'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> _getExistingCommunityMembers(String communityId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'displayName': data['displayName'] as String? ?? '',
        'phoneNumber': data['phoneNumber'] as String? ?? '',
        'email': data['email'] as String? ?? '',
      };
    }).toList();
  }
  // Convert virtual user to real user by transferring all data and deleting virtual entry
  Future<void> convertVirtualUser(String virtualUserId, String realUserId) async {
    developer.log('Converting virtual user $virtualUserId → real user $realUserId');

    try {
      // 1. Fetch both user documents first
      final virtualUserSnap = await _firestore.collection('users').doc(virtualUserId).get();
      if (!virtualUserSnap.exists) {
        throw Exception('Virtual user not found');
      }
      final virtualData = virtualUserSnap.data()!;
      final communityId = virtualData['communityId'] as String?;

      final realUserSnap = await _firestore.collection('users').doc(realUserId).get();
      if (!realUserSnap.exists) {
        throw Exception('Real user not found');
      }
      final realData = realUserSnap.data()!;
      final realUserName = realData['displayName'] as String? ?? realData['email'] as String? ?? 'User';
      final realUserEmail = realData['email'] as String? ?? '';

      // 2. Transfer contributions (userId → realUserId)
      var contributionsQuery = _firestore
          .collection('contributions')
          .where('userId', isEqualTo: virtualUserId);
      if (communityId != null) {
        contributionsQuery = contributionsQuery.where('communityId', isEqualTo: communityId);
      }
      final contributionsSnap = await contributionsQuery.get();

      if (contributionsSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in contributionsSnap.docs) {
          batch.update(doc.reference, {
            'userId': realUserId,
            'contributorName': realUserName,
          });
        }
        await batch.commit();
        developer.log('✅ Transferred ${contributionsSnap.docs.length} contributions');
      }

      // 3. Transfer participants (userId, userName, userEmail → real user)
      var participantsQuery = _firestore
          .collection('participants')
          .where('userId', isEqualTo: virtualUserId);
      if (communityId != null) {
        participantsQuery = participantsQuery.where('communityId', isEqualTo: communityId);
      }
      final participantsSnap = await participantsQuery.get();

      if (participantsSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in participantsSnap.docs) {
          batch.update(doc.reference, {
            'userId': realUserId,
            'userName': realUserName,
            'userEmail': realUserEmail,
          });
        }
        await batch.commit();
        developer.log('✅ Transferred ${participantsSnap.docs.length} participants');
      }

      // 4. Transfer deleted_contributions
      var deletedContribQuery = _firestore
          .collection('deleted_contributions')
          .where('userId', isEqualTo: virtualUserId);
      if (communityId != null) {
        deletedContribQuery = deletedContribQuery.where('communityId', isEqualTo: communityId);
      }
      final deletedContribSnap = await deletedContribQuery.get();

      if (deletedContribSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in deletedContribSnap.docs) {
          batch.update(doc.reference, {
            'userId': realUserId,
            'contributorName': realUserName,
          });
        }
        await batch.commit();
        developer.log('✅ Transferred ${deletedContribSnap.docs.length} deleted contributions');
      }

      // 5. Transfer expenses (paidBy, paidByName)
      var expensesQuery = _firestore
          .collection('expenses')
          .where('paidBy', isEqualTo: virtualUserId);
      if (communityId != null) {
        expensesQuery = expensesQuery.where('communityId', isEqualTo: communityId);
      }
      final expensesSnap = await expensesQuery.get();

      if (expensesSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in expensesSnap.docs) {
          batch.update(doc.reference, {
            'paidBy': realUserId,
            'paidByName': realUserName,
          });
        }
        await batch.commit();
        developer.log('✅ Transferred ${expensesSnap.docs.length} expenses');
      }

      // 6. Delete virtual user (transaction for atomicity)
      await _firestore.runTransaction((transaction) async {
        transaction.delete(_firestore.collection('users').doc(virtualUserId));

        if (communityId != null) {
          transaction.delete(
            _firestore
                .collection('communities')
                .doc(communityId)
                .collection('virtualUsers')
                .doc(virtualUserId),
          );
        }
      });

      // 7. Clear cache
      if (communityId != null) {
        _clearCacheForCommunity(communityId);
      }

      developer.log('✅ Successfully converted virtual user $virtualUserId → $realUserId');
    } catch (e, stackTrace) {
      developer.log('Failed to convert virtual user: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}







