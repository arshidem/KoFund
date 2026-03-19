import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/auth/models/user_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  /// Fetch all users in the app (for admin)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await usersCollection.limit(100).get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw 'Failed to load users: $e';
    }
  }

  // In your UserService or ParticipantService
  Future<bool> isUserInProgram(String userId, String programId) async {
    try {
      debugPrint('🔍 DEBUG: Checking if user $userId is ACTIVE participant in program $programId');
      
      final snapshot = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .limit(1)
          .get();
      
      final isActiveParticipant = snapshot.docs.isNotEmpty;
      debugPrint('📊 DEBUG: User $userId is ACTIVE participant in program $programId: $isActiveParticipant');
      
      return isActiveParticipant;
    } catch (e) {
      debugPrint('❌ DEBUG: Error checking program participation: $e');
      throw Exception('Failed to check program participation: $e');
    }
  }

  /// Fetch all users in a specific community
  Future<List<UserModel>> getUsersByCommunity(
    String communityId, {
    String filterType = 'all', // 'all', 'real', 'virtual'
    bool includeUnapproved = false,
  }) async {
    try {
      debugPrint('🔍 DEBUG: Fetching $filterType users for community $communityId (includeUnapproved: $includeUnapproved)');
      
      if (filterType == 'real') {
        debugPrint('🎯 REAL USERS STRATEGY: Getting users and filtering in code');
        
        Query query = usersCollection
            .where('communityId', isEqualTo: communityId);
        
        // Only filter by isApproved if not including unapproved
        if (!includeUnapproved) {
          query = query.where('isApproved', isEqualTo: true);
        }
        
        query = query.orderBy('displayName').limit(200);
        
        final snapshot = await query.get();
        debugPrint('📥 DEBUG: Retrieved ${snapshot.docs.length} users from Firestore');
        
        final users = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['isVirtualUser'] = data['isVirtualUser'] ?? false;
          data['isApproved'] = data['isApproved'] ?? true;
          
          return UserModel.fromMap(data);
        }).where((user) {
          final isReal = !user.isVirtualUser;
          final isApprovedMatch = includeUnapproved || user.isApproved;
          return isReal && isApprovedMatch;
        }).toList();
        
        debugPrint('✅ DEBUG: After filtering - got ${users.length} users');
        return users;
        
      } else {
        debugPrint('🎯 ${filterType.toUpperCase()} USERS: Querying directly');
        
        Query query = usersCollection
            .where('communityId', isEqualTo: communityId);
            
        // Only filter by isApproved if not including unapproved
        if (!includeUnapproved) {
          query = query.where('isApproved', isEqualTo: true);
        }
        
        query = query.orderBy('displayName').limit(200);
        
        if (filterType == 'virtual') {
          query = query.where('isVirtualUser', isEqualTo: true);
          debugPrint('🎯 Added isVirtualUser = true filter');
        }
        
        final snapshot = await query.get();
        debugPrint('✅ DEBUG: Retrieved ${snapshot.docs.length} $filterType users');
        
        final users = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['isVirtualUser'] = data['isVirtualUser'] ?? false;
          data['isApproved'] = data['isApproved'] ?? true;
          
          return UserModel.fromMap(data);
        }).toList();
        
        return users;
      }
      
    } catch (e) {
      debugPrint('❌ DEBUG: Error fetching community members: $e');
      throw 'Failed to fetch community members: $e';
    }
  }

  /// Get pending users (not approved yet)
  Future<List<UserModel>> getPendingUsers(String communityId) async {
    try {
      final snapshot = await usersCollection
          .where('communityId', isEqualTo: communityId)
          .where('isApproved', isEqualTo: false)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw 'Failed to fetch pending users: $e';
    }
  }

  /// Approve a pending user
  Future<void> approveUser(String uid) async {
    try {
      await usersCollection.doc(uid).update({
        'isApproved': true,
        'role': 'member', // or 'admin'
        'approvedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Failed to approve user: $e';
    }
  }

  /// Reject user (removes community info completely)
  Future<void> rejectUser(String uid, String communityId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // References
      final userRef = usersCollection.doc(uid);
      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId);
      final memberRef = communityRef.collection('members').doc(uid);

      // 1. Clear user's community data
      batch.update(userRef, {
        'communityId': FieldValue.delete(),
        'communityCode': FieldValue.delete(),
        'communityName': FieldValue.delete(),
        'role': FieldValue.delete(),
        'isApproved': false,
        'isAdmin': false,
        'approvedAt': FieldValue.delete(),
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedByAdmin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Remove user from community members subcollection
      batch.delete(memberRef);

      // 3. Increment/Decrement appropriate counter in community
      // (Simplified logic: we just decrement members if not pending)
      batch.update(communityRef, {
        'totalMembers': FieldValue.increment(-1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ Admin rejected user $uid from community $communityId');
      
    } catch (e) {
      debugPrint('❌ Error rejecting user: $e');
      throw 'Failed to reject user: $e';
    }
  }

  /// Unapprove user (make inactive but keep community link)
  Future<void> unapproveUser(String uid) async {
    try {
      await usersCollection.doc(uid).update({
        'isApproved': false,
        'isAdmin': false,
      });
    } catch (e) {
      throw 'Failed to unapprove user: $e';
    }
  }

  /// Update user role
  Future<void> updateUserRole(String uid, bool isAdmin) async {
    try {
      await usersCollection.doc(uid).update({
        'isAdmin': isAdmin,
        'role': isAdmin ? 'admin' : 'member',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update user role: $e';
    }
  }

  /// Update user's profile (displayName, phone)
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? phoneNumber,
  }) async {
    try {
      await usersCollection.doc(uid).update({
        if (displayName != null) 'displayName': displayName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update user profile: $e';
    }
  }

  /// Update user's privacy settings
  Future<void> updateUserPrivacySettings(String uid, bool showDetailedProfile) async {
    try {
      await usersCollection.doc(uid).update({
        'showDetailedProfile': showDetailedProfile,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update privacy settings: $e';
    }
  }

  /// Delete current user's account
  Future<void> deleteUser(String uid) async {
    try {
      await usersCollection.doc(uid).delete();
    } catch (e) {
      throw 'Failed to delete your account: $e';
    }
  }

  /// Leave community
  Future<void> leaveCommunity(String uid, String communityId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = usersCollection.doc(uid);
      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId);
      final memberRef = communityRef.collection('members').doc(uid);

      batch.update(userRef, {
        'communityId': FieldValue.delete(),
        'communityName': FieldValue.delete(),
        'communityCode': FieldValue.delete(),
        'role': FieldValue.delete(),
        'isApproved': false,
        'isAdmin': false,
        'approvedAt': FieldValue.delete(),
        'leftAt': FieldValue.serverTimestamp(),
      });

      batch.delete(memberRef);

      batch.update(communityRef, {
        'totalMembers': FieldValue.increment(-1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ User $uid successfully left community $communityId');
      
    } catch (e) {
      debugPrint('❌ Error leaving community: $e');
      throw 'Failed to leave community: $e';
    }
  }

  /// Remove user from community (by admin)
  Future<void> removeFromCommunity(String uid, String communityId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final userRef = usersCollection.doc(uid);
      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId);
      final memberRef = communityRef.collection('members').doc(uid);

      batch.update(userRef, {
        'communityId': FieldValue.delete(),
        'communityName': FieldValue.delete(),
        'communityCode': FieldValue.delete(),
        'role': FieldValue.delete(),
        'isApproved': false,
        'isAdmin': false,
        'approvedAt': FieldValue.delete(),
        'removedAt': FieldValue.serverTimestamp(),
        'removedByAdmin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.delete(memberRef);

      batch.update(communityRef, {
        'totalMembers': FieldValue.increment(-1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ Admin removed user $uid from community $communityId');
      
    } catch (e) {
      debugPrint('❌ Error removing user from community: $e');
      throw 'Failed to remove user from community: $e';
    }
  }

  /// Fetch a single user by UID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch user: $e';
    }
  }
}
