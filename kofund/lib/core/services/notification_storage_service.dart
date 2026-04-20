import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:kofund/core/constants/notification_types.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ⭐ NEW: Key for storing current user ID locally
  static const String _currentUserIdKey = 'current_notification_user_id';

  Future<void> init() async {
    try {
      // ⭐ NEW: Check for orphaned notifications on init
      await _cleanupOrphanedNotifications();
      debugPrint("✅ NotificationStorageService initialized");
    } catch (e) {
      debugPrint("⚠️ Init cleanup error (non-critical): $e");
    }
  }

  // ⭐ NEW: Store current user ID locally for validation
  Future<void> _storeCurrentUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserIdKey, userId);
      debugPrint("📝 Stored current user ID for notification validation: $userId");
    } catch (e) {
      debugPrint("❌ Error storing user ID: $e");
    }
  }

  // ⭐ NEW: Get stored user ID
  Future<String?> _getStoredUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentUserIdKey);
    } catch (e) {
      debugPrint("❌ Error getting stored user ID: $e");
      return null;
    }
  }

  // ⭐ NEW: Clear stored user ID
  Future<void> _clearStoredUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserIdKey);
      debugPrint("🧹 Cleared stored user ID");
    } catch (e) {
      debugPrint("❌ Error clearing stored user ID: $e");
    }
  }

  // ⭐ UPDATED: Save notification with enhanced validation
Future<void> saveNotification(AppNotification notification) async {
  try {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ No user logged in, cannot save notification');
      return;
    }

    // 🚨 CRITICAL CHECK 1: Is this notification for the CURRENT user?
    if (notification.userId != user.uid) {
      debugPrint('⚠️ Attempting to save notification for different user!');
      debugPrint('   Notification userId: ${notification.userId}');
      debugPrint('   Current userId: ${user.uid}');
      return;
    }

    // ⭐ NEW: Check with stored user ID as well
    final storedUserId = await _getStoredUserId();
    if (storedUserId != null && storedUserId != user.uid) {
      debugPrint('⚠️ Stored user ID mismatch!');
      debugPrint('   Stored userId: $storedUserId');
      debugPrint('   Current userId: ${user.uid}');
      // Update stored user ID
      await _storeCurrentUserId(user.uid);
    }

    // ⭐ NEW: Community validation (if notification has community)
    if (notification.communityId != null && notification.communityId!.isNotEmpty) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userCommunities = (userDoc.data()?['notificationCommunities'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      
      if (!userCommunities.contains(notification.communityId)) {
        debugPrint('⚠️ User not in notification community!');
        debugPrint('   Notification community: ${notification.communityId}');
        debugPrint('   User communities: ${userCommunities.join(', ')}');
        return;
      }
    }

    // 🆕 Check if notification with this ID already exists
    final existingDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notification.id)
        .get();

    if (existingDoc.exists) {
      debugPrint('⚠️ Notification ${notification.id} already exists in Firestore, skipping');
      return;
    }

    // ⭐ NEW: Store current user ID if not already stored
    if (storedUserId == null) {
      await _storeCurrentUserId(user.uid);
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toFirestore());
    
    debugPrint('✅ Notification saved: ${notification.id}');
    
  } catch (e) {
    debugPrint('❌ Error saving notification: $e');
  }
}

  // ⭐ NEW: Save notification for specific user (admin use)
  Future<void> saveNotificationForUser({
    required String userId,
    required AppNotification notification,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      // ⭐ NEW: Verify admin/sender permissions
      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final isAdmin = currentUserDoc.data()?['role'] == 'admin';
      
      // Check if sender and receiver share a community
      final senderCommunities = (currentUserDoc.data()?['notificationCommunities'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      
      if (notification.communityId != null && !senderCommunities.contains(notification.communityId)) {
        debugPrint("❌ Sender not in notification community");
        return;
      }
      
      if (!isAdmin && currentUser.uid != userId) {
        debugPrint("❌ Only admins can save notifications for other users");
        return;
      }
      
      // Save notification
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toFirestore());
      
      debugPrint('✅ Notification saved for user $userId: ${notification.id}');
      
    } catch (e) {
      debugPrint('❌ Error saving notification for user: $e');
    }
  }

  // ⭐ UPDATED: Mark as read with validation
  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // ⭐ NEW: Verify notification belongs to current user
      final notificationDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (!notificationDoc.exists) {
        debugPrint('⚠️ Notification $notificationId not found for user ${user.uid}');
        return;
      }
      
      final notificationData = notificationDoc.data();
      if (notificationData?['userId'] != user.uid) {
        debugPrint('⚠️ Notification $notificationId does not belong to user ${user.uid}');
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
          
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // ⭐ UPDATED: Mark all as read with validation
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .where('userId', isEqualTo: user.uid) // Extra safety filter
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      if (notifications.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('✅ Marked ${notifications.docs.length} notifications as read');
      }
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  // ⭐ UPDATED: Get notifications stream with community filtering
  Stream<List<AppNotification>> getNotificationsStream({
    String? filterByCommunity,
    NotificationType? filterByType,
  }) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    Query query = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('userId', isEqualTo: user.uid) // Base filter
        .orderBy('timestamp', descending: true);

    // ⭐ NEW: Apply community filter if specified
    if (filterByCommunity != null && filterByCommunity.isNotEmpty) {
      query = query.where('communityId', isEqualTo: filterByCommunity);
    }
    
    // ⭐ NEW: Apply type filter if specified
    if (filterByType != null) {
      query = query.where('type', isEqualTo: filterByType.name);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) {
          try {
            return AppNotification.fromFirestore(doc);
          } catch (e) {
            debugPrint('❌ Error parsing notification ${doc.id}: $e');
            return AppNotification(
              id: 'error',
              title: 'Error',
              body: 'Could not load notification',
              type: NotificationType.announcement,
              timestamp: DateTime.now(),
            );
          }
        })
        .toList());
  }

  // ⭐ NEW: Get notifications by community
  Future<List<AppNotification>> getNotificationsByCommunity(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('communityId', isEqualTo: communityId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting notifications by community: $e');
      return [];
    }
  }

  // ⭐ NEW: Get unread count by community
  Future<int> getUnreadCountByCommunity(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .where('userId', isEqualTo: user.uid)
          .where('communityId', isEqualTo: communityId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting unread count by community: $e');
      return 0;
    }
  }

  Future<int> getUnreadCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .where('userId', isEqualTo: user.uid) // Extra safety filter
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // ⭐ UPDATED: Delete notification with validation
  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // ⭐ NEW: Verify ownership before deleting
      final notificationDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (!notificationDoc.exists) {
        debugPrint('⚠️ Notification $notificationId not found');
        return;
      }
      
      final notificationData = notificationDoc.data();
      if (notificationData?['userId'] != user.uid) {
        debugPrint('⚠️ Cannot delete notification that does not belong to user');
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
          
      debugPrint('✅ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  // ⭐ UPDATED: Clear all notifications with validation
  Future<void> clearAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('userId', isEqualTo: user.uid) // Only delete user's own
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      if (notifications.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('✅ Cleared ${notifications.docs.length} notifications');
      }
    } catch (e) {
      debugPrint('❌ Error clearing all notifications: $e');
    }
  }

  // ⭐ NEW: Cleanup orphaned notifications (for wrong user)
  Future<void> _cleanupOrphanedNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      debugPrint('🧹 Checking for orphaned notifications...');
      
      final notifications = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();
      
      int orphanedCount = 0;
      final batch = _firestore.batch();
      
      for (final doc in notifications.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final notificationUserId = data?['userId'] as String?;
        
        if (notificationUserId != user.uid) {
          batch.delete(doc.reference);
          orphanedCount++;
          debugPrint('   🗑️ Deleting orphaned notification: ${doc.id}');
        }
      }
      
      if (orphanedCount > 0) {
        await batch.commit();
        debugPrint('✅ Deleted $orphanedCount orphaned notifications');
      } else {
        debugPrint('✅ No orphaned notifications found');
      }
      
    } catch (e) {
      debugPrint('⚠️ Error cleaning orphaned notifications: $e');
    }
  }

  // ⭐ NEW: Cleanup notifications for logged out user
  Future<void> cleanupForUserLogout() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('🔐 User still logged in, skipping logout cleanup');
        return;
      }
      
      // Get stored user ID
      final storedUserId = await _getStoredUserId();
      if (storedUserId == null) {
        debugPrint('📭 No stored user ID found');
        return;
      }
      
      // Clear stored user ID
      await _clearStoredUserId();
      debugPrint('✅ Cleared stored user ID for logout');
      
    } catch (e) {
      debugPrint('❌ Error during logout cleanup: $e');
    }
  }

  // ⭐ NEW: Update user's communities in stored notifications
  Future<void> updateNotificationCommunities(List<String> communityIds) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // ⭐ NEW: Store user's communities for validation
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_communities', communityIds);
      
      debugPrint('✅ Updated user communities in storage: ${communityIds.join(', ')}');
    } catch (e) {
      debugPrint('❌ Error updating notification communities: $e');
    }
  }

  // 🆕 NEW: Debug function to check what's in Firestore
  Future<void> debugUserNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('🔐 No user logged in');
      return;
    }

    try {
      debugPrint('🔍 ===== DEBUG NOTIFICATIONS FOR USER: ${user.uid} =====');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      debugPrint('📊 Total notifications: ${snapshot.docs.length}');
      
      // Get stored user ID for comparison
      final storedUserId = await _getStoredUserId();
      debugPrint('📝 Stored user ID: $storedUserId');
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('\n📋 ID: ${doc.id}');
        debugPrint('   Title: ${data['title']}');
        debugPrint('   userId in data: ${data['userId']}');
        debugPrint('   Is for current user? ${data['userId'] == user.uid}');
        debugPrint('   Matches stored ID? ${data['userId'] == storedUserId}');
        debugPrint('   Community: ${data['communityId'] ?? "N/A"}');
        debugPrint('   Type: ${data['type']}');
        debugPrint('   isRead: ${data['isRead']}');
        debugPrint('   timestamp: ${data['timestamp']}');
      }
    } catch (e) {
      debugPrint('❌ Debug error: $e');
    }
  }
}
