import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;
import '../../../features/auth/models/user_model.dart';

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
        final sanitizedName = _sanitizeNameForEmail(displayName);
        final virtualEmail = email ?? '$sanitizedName@virtual.kofund.app';

        // Check for duplicate in transaction
        final query = _firestore
            .collection('users')
            .where('communityId', isEqualTo: communityId)
            .where('displayName', isEqualTo: displayName.trim())
            .where('isVirtualUser', isEqualTo: true)
            .limit(1);
        
        final duplicateCheck = await query.get(); // Get QuerySnapshot

        if (duplicateCheck.docs.isNotEmpty) {
          throw Exception('A virtual user with name "$displayName" already exists in this community');
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
  Future<List<UserModel>> createMultipleVirtualUsers({
    required String communityId,
    required String adminUid,
    required List<Map<String, dynamic>> usersData,
  }) async {
    developer.log('Creating ${usersData.length} virtual users for community: $communityId');

    try {
      // Validate all users first
      for (int i = 0; i < usersData.length; i++) {
        final user = usersData[i];
        final name = user['name'] as String? ?? '';
        final phone = user['phone'] as String?;
        final email = user['email'] as String?;

        _validateUserInputs(
          displayName: name,
          phoneNumber: phone,
          email: email,
        );
      }

      // Check for duplicates before starting batch
      final existingNames = await _getExistingVirtualUserNames(communityId);
      final duplicateNames = <String>[];
      
      for (final userData in usersData) {
        final name = (userData['name'] as String).trim();
        if (existingNames.contains(name)) {
          duplicateNames.add(name);
        }
      }

      if (duplicateNames.isNotEmpty) {
        throw Exception('Duplicate names found: ${duplicateNames.join(', ')}. Please use unique names.');
      }

      final batch = _firestore.batch();
      final createdUsers = <UserModel>[];

      for (final userData in usersData) {
        final virtualUserId = 'virtual_${_uuid.v4()}';
        final displayName = (userData['name'] as String).trim();
        final phoneNumber = userData['phone'] as String?;
        final email = userData['email'] as String?;
        final sanitizedName = _sanitizeNameForEmail(displayName);
        final virtualEmail = email ?? '$sanitizedName@virtual.kofund.app';

        final virtualUser = UserModel(
          uid: virtualUserId,
          email: virtualEmail,
          displayName: displayName,
          phoneNumber: phoneNumber?.trim(),
          communityId: communityId,
          communityName: null,
          role: 'member',
          isApproved: true,
          isAdmin: false,
          isDeveloper: false,
          isVirtualUser: true,
          createdBy: adminUid,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          showDetailedProfile: false,
        );

        // Add to batch
        final userRef = _firestore.collection('users').doc(virtualUserId);
        batch.set(userRef, virtualUser.toMap());

        final communityUserRef = _firestore
            .collection('communities')
            .doc(communityId)
            .collection('virtualUsers')
            .doc(virtualUserId);
        
        batch.set(communityUserRef, {
          'uid': virtualUserId,
          'displayName': displayName,
          'phoneNumber': phoneNumber?.trim(),
          'email': virtualEmail,
          'createdBy': adminUid,
          'createdAt': Timestamp.now(),
          'isActive': true,
          'status': 'active',
          'updatedAt': Timestamp.now(),
        });

        createdUsers.add(virtualUser);
      }

      await batch.commit();
      
      // Clear cache for this community
      _clearCacheForCommunity(communityId);
      
      developer.log('Successfully created ${createdUsers.length} virtual users');
      return createdUsers;
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
      
      print('✅ DEBUG: Virtual user $userId updated successfully');
    } catch (e) {
      print('❌ DEBUG: Error updating virtual user: $e');
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


  // Delete virtual user
  Future<void> deleteVirtualUser(String userId) async {
    developer.log('Deleting virtual user: $userId');

    try {
      await _firestore.runTransaction((transaction) async {
        // Get current user data
        final userDoc = await transaction.get(_firestore.collection('users').doc(userId));
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final communityId = userData['communityId'] as String?;
        
        if (communityId == null) {
          throw Exception('Community ID not found for user');
        }

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

      final batch = _firestore.batch();
      final Set<String> communityIds = {};

      // First, get all users to find their community IDs
      for (final userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final communityId = userDoc.data()?['communityId'] as String?;
          if (communityId != null) {
            communityIds.add(communityId);
            
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

      developer.log('Successfully deleted ${userIds.length} virtual users');
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
      final emailMatch = user.email?.toLowerCase().contains(lowerQuery) == true;
      
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

  String _sanitizeNameForEmail(String name) {
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

  Future<Set<String>> _getExistingVirtualUserNames(String communityId) async {
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
}