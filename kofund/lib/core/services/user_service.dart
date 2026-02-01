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
      final snapshot = await usersCollection.get();
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
          .where('status', isEqualTo: 'joined') // ✅ ADD THIS - only active participants
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

/// Fetch all users in a specific community with optional pagination
Future<List<UserModel>> getUsersByCommunity(
  String communityId, {
  String filterType = 'all', // 'all', 'real', 'virtual'
  int limit = 100, // Default to 100 for backward compatibility
  DocumentSnapshot? lastDocument, // For pagination
  bool loadMore = false, // Whether to load next page
}) async {
  try {
    debugPrint('🔍 DEBUG: Fetching $filterType users for community $communityId');
    
    if (filterType == 'real') {
      debugPrint('🎯 REAL USERS STRATEGY: Getting all users and filtering in code');
      
      // For real users, we need to get ALL users first, then filter
      // because real users might not have the isVirtualUser field
      Query query = usersCollection
          .where('communityId', isEqualTo: communityId)
          .orderBy('displayName')
          .limit(limit * 3); // Get more to account for filtering
      
      if (loadMore && lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
        debugPrint('📄 DEBUG: Loading next page from cursor');
      }
      
      debugPrint('📊 DEBUG: Executing query with limit ${limit * 3} for real users (will filter)');
      
      final snapshot = await query.get();
      debugPrint('📥 DEBUG: Retrieved ${snapshot.docs.length} total users from Firestore');
      
      // Convert and filter in code
      final users = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // IMPORTANT: Default isVirtualUser to false if field is missing
        // Missing field means it's a real user
        data['isVirtualUser'] = data['isVirtualUser'] ?? false;
        data['isApproved'] = data['isApproved'] ?? true;
        
        return UserModel.fromMap(data);
      }).where((user) => !user.isVirtualUser) // Filter out virtual users
        .take(limit) // Apply limit after filtering
        .toList();
      
      debugPrint('✅ DEBUG: After filtering - got ${users.length} real users');
      return users;
      
    } else {
      // For 'all' and 'virtual' users, we can query directly
      debugPrint('🎯 $filterType.toUpperCase() USERS: Querying directly');
      
      Query query = usersCollection
          .where('communityId', isEqualTo: communityId)
          .orderBy('displayName')
          .limit(limit);
      
      // Apply server-side filtering for virtual users
      if (filterType == 'virtual') {
        query = query.where('isVirtualUser', isEqualTo: true);
        debugPrint('🎯 Added isVirtualUser = true filter');
      }
      // For 'all', no additional filter
      
      // Apply pagination if loading more
      if (loadMore && lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
        debugPrint('📄 DEBUG: Loading next page from cursor');
      }
      
      debugPrint('📊 DEBUG: Executing query with limit $limit for $filterType users');
      
      final snapshot = await query.get();
      debugPrint('✅ DEBUG: Retrieved ${snapshot.docs.length} $filterType users');
      
      // Convert documents to UserModel
      final users = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Ensure required fields exist
        // For 'all' query: default isVirtualUser to false if missing
        // For 'virtual' query: should already have isVirtualUser = true
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
      'communityName': FieldValue.delete(), // Keep if your UserModel has it
      'role': FieldValue.delete(),
      'isApproved': false,
      'isAdmin': false,
      'approvedAt': FieldValue.delete(),
      'rejectedAt': FieldValue.serverTimestamp(), // Add timestamp for rejection
      'rejectedByAdmin': true, // Flag to distinguish
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Remove user from community members subcollection
    batch.delete(memberRef);

    // 3. Check if user was pending to decrement correct counter
    final memberDoc = await memberRef.get();
    final isPending = memberDoc.exists ? 
        (memberDoc.data()?['isApproved'] == false) : false;

    // 4. Decrement appropriate counter in community
    if (isPending) {
      batch.update(communityRef, {
        'pendingMembers': FieldValue.increment(-1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(communityRef, {
        'totalMembers': FieldValue.increment(-1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    }

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

  // ✅ ADD THIS MISSING METHOD: Update user role
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

  /// ✅ FIXED: Update user's profile (displayName, phone)
  Future<void> updateUserProfile({
    required String uid,
    String? displayName, // ✅ CHANGED: name → displayName
    String? phoneNumber,
  }) async {
    try {
      await usersCollection.doc(uid).update({
        if (displayName != null) 'displayName': displayName, // ✅ CHANGED: 'name' → 'displayName'
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update user profile: $e';
    }
  }

  // Add this to your UserService class
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

  /// Delete current user's account (self-delete only)
  Future<void> deleteUser(String uid) async {
    try {
      await usersCollection.doc(uid).delete();
    } catch (e) {
      throw 'Failed to delete your account: $e';
    }
  }

/// Leave community (for normal users)
Future<void> leaveCommunity(String uid, String communityId) async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    final userRef = usersCollection.doc(uid);
    final communityRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId);
    final memberRef = communityRef.collection('members').doc(uid);

    // 1. Update user document
    batch.update(userRef, {
      'communityId': FieldValue.delete(),
      'communityName': FieldValue.delete(),
      'communityCode': FieldValue.delete(), // 🆕 Also remove invite code
      'role': FieldValue.delete(),
      'isApproved': false,
      'isAdmin': false,
      'approvedAt': FieldValue.delete(),
      'leftAt': FieldValue.serverTimestamp(),
      // ✅ Keep: 'uid', 'email', 'displayName', 'phoneNumber', 'createdAt', 'showDetailedProfile'
    });

    // 2. Remove user from community members subcollection
    batch.delete(memberRef);

    // 3. Decrement total members count in community
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

Future<void> removeFromCommunity(String uid, String communityId) async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    
    // References to all documents involved
    final userRef = usersCollection.doc(uid);
    final communityRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId);
    final memberRef = communityRef.collection('members').doc(uid);

    // 1. Clear user's community data
    batch.update(userRef, {
      'communityId': FieldValue.delete(),  // Use delete instead of null
      'communityName': FieldValue.delete(), // Use delete instead of null
      'communityCode': FieldValue.delete(), // 🆕 Also remove invite code
      'role': FieldValue.delete(),
      'isApproved': false,
      'isAdmin': false,
      'approvedAt': FieldValue.delete(),
      'removedAt': FieldValue.serverTimestamp(), // Add timestamp for removal
      'removedByAdmin': true, // Flag to distinguish from voluntary leaving
      'updatedAt': FieldValue.serverTimestamp(),
      // ✅ Keep: 'uid', 'email', 'displayName', 'phoneNumber', 'createdAt', 'showDetailedProfile'
    });

    // 2. Remove user from community members subcollection
    batch.delete(memberRef);

    // 3. Check if user was pending to decide which counter to decrement
    final memberDoc = await memberRef.get();
    final isPending = memberDoc.exists ? 
        (memberDoc.data()?['isApproved'] == false) : false;

    // 4. Decrement appropriate counter in community
    if (isPending) {
      batch.update(communityRef, {
        'pendingMembers': FieldValue.increment(-1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(communityRef, {
        'totalMembers': FieldValue.increment(-1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    }

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



























