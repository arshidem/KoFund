import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/auth/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:intl/intl.dart';

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
  Future<bool> isUserInEvent(String userId, String eventId, {String? communityId}) async {
    try {
      debugPrint('🔍 DEBUG: Checking if user $userId is ACTIVE participant in event $eventId');
      
      var query = _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'joined');
      
      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final snapshot = await query.limit(1).get();
      
      final isActiveParticipant = snapshot.docs.isNotEmpty;
      debugPrint('📊 DEBUG: User $userId is ACTIVE participant in event $eventId: $isActiveParticipant');
      
      return isActiveParticipant;
    } catch (e) {
      debugPrint('❌ DEBUG: Error checking event participation: $e');
      throw Exception('Failed to check event participation: $e');
    }
  }

  /// Fetch all users in a specific community
  Future<List<UserModel>> getUsersByCommunity(
    String communityId, {
    String filterTeventType = 'all', // 'all', 'real', 'virtual'
    bool includeUnapproved = false,
  }) async {
    try {
      debugPrint('🔍 DEBUG: Fetching $filterTeventType users for community $communityId (includeUnapproved: $includeUnapproved)');
      
      debugPrint('🎯 ${filterTeventType.toUpperCase()} USERS: Querying directly');
      
      Query query = usersCollection
          .where('communityId', isEqualTo: communityId);
          
      if (!includeUnapproved) {
        query = query.where('isApproved', isEqualTo: true);
      }
      
      if (filterTeventType == 'virtual') {
        query = query.where('isVirtualUser', isEqualTo: true);
      }
      
      query = query.orderBy('displayName').limit(200);
      
      final snapshot = await query.get();
      debugPrint('✅ DEBUG: Retrieved ${snapshot.docs.length} $filterTeventType users');
      
      final users = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['isVirtualUser'] = data['isVirtualUser'] ?? false;
        data['isApproved'] = data['isApproved'] ?? true;
        return UserModel.fromMap(data);
      }).toList();

      if (filterTeventType == 'real') {
        return users.where((u) => !u.isVirtualUser).toList();
      }
      return users;
      
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
  Future<void> approveUser(String uid, {String? adminName}) async {
    try {
      await usersCollection.doc(uid).update({
        'isApproved': true,
        'role': 'member', // or 'admin'
        'approvedAt': Timestamp.now(),
        if (adminName != null) 'approvedBy': adminName,
      });

      // 🔔 Trigger Notification to User (You're In! 🎉)
      try {
        final notificationService = NotificationService();
        
        // Fetch user data to get community info
        String communityName = 'the community';
        String? communityLogo;
        final userDoc = await usersCollection.doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          communityName = userData?['communityName'] ?? 'the community';
          final communityId = userData?['communityId'];
          
          if (communityId != null) {
            final communityDoc = await _firestore.collection('communities').doc(communityId).get();
            if (communityDoc.exists) {
              communityLogo = communityDoc.data()?['logoUrl'];
            }
          }
        }

        // Fire and forget to avoid blocking the UI
        notificationService.sendUserNotification(
          userId: uid,
          title: 'You\'re In! 🎉',
          body: 'Your request to join $communityName has been approved.',
          type: NotificationType.approval,
          senderName: adminName,
          data: {
            'deepLink': '/community/home',
            'communityName': communityName,
            'communityLogo': communityLogo, // ✅ Add logo
            'approvedAt': DateFormat('MMM dd, yyyy · hh:mm a').format(DateTime.now()),
            'approvedBy': adminName ?? 'Admin',
          },
        ).catchError((e) {
          debugPrint('⚠️ Approval notification background failed: $e');
        });
      } catch (e) {
        debugPrint('⚠️ Approval notification setup failed: $e');
      }
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

  /// Update user's notification settings
  Future<void> updateUserNotificationSettings(String uid, bool enabled) async {
    try {
      await usersCollection.doc(uid).update({
        'notificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update notification settings: $e';
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





