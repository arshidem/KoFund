import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/auth/models/user_model.dart';

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
      print('🔍 DEBUG: Checking if user $userId is ACTIVE participant in program $programId');
      
      final snapshot = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined') // ✅ ADD THIS - only active participants
          .limit(1)
          .get();
      
      final isActiveParticipant = snapshot.docs.isNotEmpty;
      print('📊 DEBUG: User $userId is ACTIVE participant in program $programId: $isActiveParticipant');
      
      return isActiveParticipant;
    } catch (e) {
      print('❌ DEBUG: Error checking program participation: $e');
      throw Exception('Failed to check program participation: $e');
    }
  }

  /// Fetch all users in a specific community
  Future<List<UserModel>> getUsersByCommunity(String communityId) async {
    try {
      final snapshot = await usersCollection
          .where('communityId', isEqualTo: communityId)
          .get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
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
  Future<void> rejectUser(String uid) async {
    try {
      await usersCollection.doc(uid).update({
        'communityId': FieldValue.delete(),
        'communityCode': FieldValue.delete(),
        // 'communityName': FieldValue.delete(), // ❌ REMOVE if not in UserModel
        'role': FieldValue.delete(),
        'isApproved': false,
        'isAdmin': false,
        'approvedAt': FieldValue.delete(),
      });
    } catch (e) {
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
  Future<void> leaveCommunity(String uid) async {
    try {
      await usersCollection.doc(uid).update({
        'communityId': FieldValue.delete(),
        'communityCode': FieldValue.delete(),
        // 'communityName': FieldValue.delete(), // ❌ REMOVE if not in UserModel
        'role': FieldValue.delete(),
        'isApproved': false,
        'isAdmin': false,
        'approvedAt': FieldValue.delete(),
        'leftAt': FieldValue.serverTimestamp(),
        // ✅ Keep these fields - don't delete them
        // 'uid', 'email', 'displayName', 'phoneNumber', 'createdAt', 'showDetailedProfile'
      });
      
    } catch (e) {
      throw 'Failed to leave community: $e';
    }
  }

  Future<void> removeFromCommunity(String uid) async {
    try {
      await usersCollection.doc(uid).update({
        'communityId': null,
        'communityCode': null,
        // 'communityName': null, // ❌ REMOVE if not in UserModel
        'role': null,
        'isApproved': false,
        'isAdmin': false,
        'approvedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
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