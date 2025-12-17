import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FCMTokenService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _currentUserIdKey = 'current_notification_user_id';

  // ⭐ NEW: Get current stored user ID from device
  Future<String?> _getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserIdKey);
  }

  // ⭐ NEW: Store current user ID on device
  Future<void> _storeUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, userId);
  }

  // ⭐ NEW: Clear stored user ID
  Future<void> _clearStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
  }
// ✅ ADD THIS AT THE TOP OF YOUR CLASS
Future<String?> _getTokenWithRetry({int maxAttempts = 5}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      debugPrint("🔄 [FCM] Token attempt $attempt/$maxAttempts...");
      
      // First check if FCM is ready by getting notification settings
      try {
        await _messaging.getNotificationSettings();
      } catch (e) {
        debugPrint("⏳ FCM not ready yet...");
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
      }
      
      final token = await _messaging.getToken();
      
      if (token != null && token.isNotEmpty) {
        debugPrint("✅ [FCM] Got token on attempt $attempt");
        return token;
      }
      
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt)); // Exponential backoff
      }
    } catch (e) {
      debugPrint("❌ [FCM] Attempt $attempt failed: $e");
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }
  return null;
}
  // ⭐ UPDATED: Store token with community context
// ⭐ UPDATED: Store token with community context
Future<void> storeCurrentUserToken({
  required List<String> communityIds,
  String? deviceId,
}) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // ⭐ CHANGE THIS: Use retry method instead of direct getToken()
    // final token = await _messaging.getToken(); // OLD
    final token = await _getTokenWithRetry(maxAttempts: 3); // NEW
    
    if (token == null) {
      debugPrint("⚠️ No FCM token available after retries");
      return;
    }
    
    debugPrint("📱 Storing token for user: ${user.uid}");
    debugPrint("   Communities: ${communityIds.join(', ')}");
    
    // ⭐ CRITICAL: Store current user ID for validation
    await _storeUserId(user.uid);
    
    // Rest of your method stays the same...
      // ⭐ CRITICAL: Clean token from other users FIRST
      await _cleanTokenFromOtherUsers(token, user.uid);
      
      // Then add to current user WITH COMMUNITY CONTEXT
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
            'fcmTokens': FieldValue.arrayUnion([token]),
            'updatedAt': FieldValue.serverTimestamp(),
            // ⭐ NEW: Store user's communities for targeted notifications
            'notificationCommunities': communityIds,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
      
      // Also store in a dedicated collection for better querying
      await _firestore
          .collection('user_notification_tokens')
          .doc(token)
          .set({
            'token': token,
            'userId': user.uid,
            'communityIds': communityIds,
            'deviceId': deviceId ?? await _getDeviceIdentifier(),
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      debugPrint('✅ Token stored with community context for user: ${user.uid}');
      
      // Also register with Cloud Function if available
      await _registerTokenWithCloudFunction(token, user.uid, communityIds);
      
    } catch (e) {
      debugPrint('❌ Error storing token: $e');
    }
  }

  // ⭐ UPDATED: Clean token from other users with community context
  Future<void> _cleanTokenFromOtherUsers(String token, String currentUserId) async {
    try {
      debugPrint("🧹 Cleaning token from other users...");
      
      // Find all users who have this token (except current user)
      final usersSnapshot = await _firestore
          .collection('users')
          .where('fcmTokens', arrayContains: token)
          .get();
      
      debugPrint("🔍 Found ${usersSnapshot.docs.length} users with this token");
      
      final batch = _firestore.batch();
      int cleanedCount = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        if (userDoc.id != currentUserId) {
          // Remove from user's tokens array
          batch.update(userDoc.reference, {
            'fcmTokens': FieldValue.arrayRemove([token])
          });
          
          // Also update in user_notification_tokens collection
          batch.update(
            _firestore.collection('user_notification_tokens').doc(token),
            {
              'isActive': false,
              'updatedAt': FieldValue.serverTimestamp(),
              'deactivatedReason': 'user_logged_out',
              'previousUserId': userDoc.id,
            }
          );
          
          cleanedCount++;
          debugPrint("   🧹 Removing from user: ${userDoc.id}");
        }
      }
      
      if (cleanedCount > 0) {
        await batch.commit();
        debugPrint("✅ Removed token from $cleanedCount other users");
      } else {
        debugPrint("✅ Token not found in other users");
      }
      
    } catch (e) {
      debugPrint("⚠️ Error cleaning token from other users: $e");
    }
  }

  // ⭐ NEW: Handle user logout - clear token from this user
  Future<void> handleUserLogout() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final token = await _messaging.getToken();
      if (token == null) return;
      
      debugPrint("🚪 Handling logout for user: ${user.uid}");
      
      // Remove token from current user's document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
            'fcmTokens': FieldValue.arrayRemove([token]),
            'notificationCommunities': FieldValue.delete(),
          });
      
      // Mark as inactive in user_notification_tokens
      await _firestore
          .collection('user_notification_tokens')
          .doc(token)
          .update({
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'deactivatedReason': 'user_logout',
            'logoutAt': FieldValue.serverTimestamp(),
          });
      
      // Clear stored user ID
      await _clearStoredUserId();
      
      debugPrint("✅ Token cleaned up for logged out user: ${user.uid}");
      
    } catch (e) {
      debugPrint("❌ Error handling logout: $e");
    }
  }

  // ⭐ NEW: Update user's communities when they join/leave communities
  Future<void> updateUserCommunities(List<String> communityIds) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final token = await _messaging.getToken();
      if (token == null) return;
      
      debugPrint("🔄 Updating communities for user: ${user.uid}");
      debugPrint("   New communities: ${communityIds.join(', ')}");
      
      // Update in user document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
            'notificationCommunities': communityIds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Update in user_notification_tokens collection
      await _firestore
          .collection('user_notification_tokens')
          .doc(token)
          .update({
            'communityIds': communityIds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint("✅ Communities updated for user: ${user.uid}");
      
    } catch (e) {
      debugPrint("❌ Error updating communities: $e");
    }
  }

  // ⭐ UPDATED: Get active tokens for a user
  Future<List<String>> getActiveTokens(String userId) async {
    try {
      debugPrint("🔍 Getting active tokens for user: $userId");
      
      // First, check if token belongs to current stored user
      final storedUserId = await _getStoredUserId();
      if (storedUserId != null && storedUserId != userId) {
        debugPrint("⚠️ Warning: Requesting tokens for non-current user!");
      }
      
      // Get from user_notification_tokens collection (primary source)
      final tokenSnapshot = await _firestore
          .collection('user_notification_tokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final tokens = tokenSnapshot.docs
          .map((doc) => doc.data()['token'] as String?)
          .where((token) => token != null && token.isNotEmpty)
          .map((token) => token!)
          .toList();
      
      debugPrint("✅ Found ${tokens.length} active tokens for user $userId");
      return tokens;
      
    } catch (e) {
      debugPrint("❌ Error getting active tokens: $e");
      return [];
    }
  }

  // ⭐ NEW: Get device identifier
  Future<String> _getDeviceIdentifier() async {
    // You might want to use a package like device_info_plus
    // For now, use a combination of platform and timestamp
    if (Platform.isIOS) {
      return 'ios_${DateTime.now().millisecondsSinceEpoch}';
    } else if (Platform.isAndroid) {
      return 'android_${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'web_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ⭐ UPDATED: Register with cloud function
  Future<void> _registerTokenWithCloudFunction(
    String token, 
    String userId,
    List<String> communityIds
  ) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('registerFCMToken');
      
      final result = await callable.call({
        'token': token,
        'userId': userId,
        'communityIds': communityIds,
        'deviceId': await _getDeviceIdentifier(),
      });
      
      final resultData = result.data as Map<String, dynamic>;
      debugPrint("✅ Token registered with Cloud Function: ${resultData['message']}");
      
    } on FirebaseFunctionsException catch (e) {
      debugPrint("⚠️ Cloud Function not available: ${e.message}");
    } catch (e) {
      debugPrint("⚠️ Error calling registerFCMToken function: $e");
    }
  }

  // ⭐ NEW: Get tokens by community ID
  Future<List<String>> getTokensByCommunity(String communityId) async {
    try {
      debugPrint("🔍 Getting tokens for community: $communityId");
      
      final tokensSnapshot = await _firestore
          .collection('user_notification_tokens')
          .where('isActive', isEqualTo: true)
          .where('communityIds', arrayContains: communityId)
          .get();
      
      final tokens = tokensSnapshot.docs
          .map((doc) => doc.data()['token'] as String?)
          .where((token) => token != null && token.isNotEmpty)
          .map((token) => token!)
          .toList();
      
      debugPrint("✅ Found ${tokens.length} tokens for community $communityId");
      return tokens;
      
    } catch (e) {
      debugPrint("❌ Error getting tokens by community: $e");
      return [];
    }
  }

// ⭐ UPDATED: Validate if notification is for current user
Future<bool> isNotificationForCurrentUser(Map<String, dynamic> notificationData) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("👤 No current user - filtering notification");
      return false;
    }
    
    // ✅ OPTIONAL: Check stored user ID (for multi-user device protection)
    final storedUserId = await _getStoredUserId();
    if (storedUserId != null && storedUserId != currentUser.uid) {
      debugPrint("⚠️ User ID mismatch: Stored $storedUserId, Current ${currentUser.uid}");
      // Don't return false here - still check community
    }
    
    // Check if notification has community ID
    final notificationCommunityId = notificationData['communityId'];
    
    // If notification doesn't have communityId, it's a global notification
    if (notificationCommunityId == null) {
      debugPrint("🌍 Global notification - showing");
      return true;
    }
    
    // Get current user's document
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    
    if (!userDoc.exists) {
      debugPrint("❌ User document not found - filtering notification");
      return false;
    }
    
    final userData = userDoc.data()!;
    
    // ✅ FIX: Get user's actual community from main field
    final userCommunityId = userData['communityId'] as String?;
    
    // ✅ FIX: Also check notificationCommunities array
    final userNotificationCommunities = (userData['notificationCommunities'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    
    debugPrint("🔍 Notification validation:");
    debugPrint("   Notification community: $notificationCommunityId");
    debugPrint("   User's communityId: $userCommunityId");
    debugPrint("   User's notificationCommunities: $userNotificationCommunities");
    
    // ✅ FIX: Check THREE possible matches:
    // 1. User's main communityId matches
    // 2. User's notificationCommunities contains it
    // 3. If user has no communities, show ALL notifications (they might be new)
    
    final isForCurrentCommunity = 
        userCommunityId == notificationCommunityId ||
        userNotificationCommunities.contains(notificationCommunityId);
    
    if (isForCurrentCommunity) {
      debugPrint("✅ Notification is for current user's community");
      return true;
    }
    
    // ✅ NEW: If user has NO communities set yet, show ALL notifications
    // (This happens for new users or when notificationCommunities wasn't set)
    if (userCommunityId == null && userNotificationCommunities.isEmpty) {
      debugPrint("📭 User has no communities set - showing notification anyway");
      debugPrint("   (User might be new or notificationCommunities wasn't set)");
      return true;
    }
    
    debugPrint("⚠️ Notification filtered: Not for current user's communities");
    return false;
    
  } catch (e) {
    debugPrint("❌ Error validating notification: $e");
    // When in doubt, show the notification (better user experience)
    return true;
  }
}

  // ⭐ UPDATED: Remove invalid token
  Future<void> removeInvalidToken(String invalidToken) async {
    try {
      final user = _auth.currentUser;
      
      // Mark as inactive in user_notification_tokens
      await _firestore
          .collection('user_notification_tokens')
          .doc(invalidToken)
          .update({
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'deactivatedReason': 'invalid_token',
          });
      
      // Remove from all users (not just current user)
      final usersWithToken = await _firestore
          .collection('users')
          .where('fcmTokens', arrayContains: invalidToken)
          .get();
      
      final batch = _firestore.batch();
      for (final userDoc in usersWithToken.docs) {
        batch.update(userDoc.reference, {
          'fcmTokens': FieldValue.arrayRemove([invalidToken])
        });
      }
      
      if (usersWithToken.docs.isNotEmpty) {
        await batch.commit();
      }
      
      debugPrint("🗑️ Removed invalid token from ${usersWithToken.docs.length} users");
      
    } catch (e) {
      debugPrint("❌ Error removing invalid token: $e");
    }
  }

  // ⭐ UPDATED: Get admin tokens (now with community context)
  Future<List<String>> getAdminTokens(String? communityId) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('emailVerified', isEqualTo: true)
          .where('isApproved', isEqualTo: true);
      
      // If communityId provided, filter admins for that community
      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final snapshot = await query.get();

      final List<String> allTokens = [];
      for (final doc in snapshot.docs) {
        final tokens = await getActiveTokens(doc.id);
        allTokens.addAll(tokens);
      }
      
      debugPrint("👑 Found ${snapshot.docs.length} admin users with ${allTokens.length} tokens");
      return allTokens;
    } catch (e) {
      debugPrint("❌ Error getting admin tokens: $e");
      return [];
    }
  }
// Add this method to FCMTokenService class
Future<bool> isUserEligibleForNotifications() async {
  try {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;
    
    final userData = userDoc.data();
    final isEmailVerified = userData?['emailVerified'] ?? false;
    final isApproved = userData?['isApproved'] ?? false;
    final hasCommunity = userData?['communityId'] != null && (userData?['communityId'] as String).isNotEmpty;
    
    debugPrint("📋 User eligibility check:");
    debugPrint("   emailVerified: $isEmailVerified");
    debugPrint("   isApproved: $isApproved");
    debugPrint("   hasCommunity: $hasCommunity");
    
    return isEmailVerified && isApproved && hasCommunity;
  } catch (e) {
    debugPrint("❌ Error checking user eligibility: $e");
    return false;
  }
}
// Add this method to FCMTokenService class
Future<void> cleanupOldTokens(String userId) async {
  try {
    // Keep only the latest 5 active tokens per user
    final tokensSnapshot = await _firestore
        .collection('user_notification_tokens')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .get();
    
    if (tokensSnapshot.docs.length > 5) {
      final batch = _firestore.batch();
      final tokensToDeactivate = tokensSnapshot.docs.skip(5);
      
      for (var doc in tokensToDeactivate) {
        batch.update(doc.reference, {
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'deactivatedReason': 'cleanup_old_tokens',
        });
      }
      
      await batch.commit();
      debugPrint("🧹 Cleaned up ${tokensToDeactivate.length} old tokens for user $userId");
    }
  } catch (e) {
    debugPrint("⚠️ Error cleaning up old tokens: $e");
  }
}
  // ⭐ UPDATED: Initialize for current user with community context
  Future<void> initializeForCurrentUser({required List<String> communityIds}) async {
    try {
      debugPrint("🚀 Initializing FCMTokenService for current user");
      
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("🔐 No user logged in");
        return;
      }
      
      // Check if user is eligible
      final isEligible = await isUserEligibleForNotifications();
      if (!isEligible) {
        debugPrint("⚠️ User not eligible for notifications");
        return;
      }
      
      // Store token with community context
      await storeCurrentUserToken(communityIds: communityIds);
      
      // Setup token refresh listener
      setupTokenRefreshListener();
      
      // Cleanup old tokens
      await cleanupOldTokens(user.uid);
      
      debugPrint("✅ FCMTokenService initialized successfully");
      
    } catch (e) {
      debugPrint("❌ Error initializing FCMTokenService: $e");
    }
  }

  // Rest of your existing methods remain similar...
  void setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token refreshed');
      final user = _auth.currentUser;
      if (user != null) {
        // Get current user's communities
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final communities = (userDoc.data()?['notificationCommunities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        
        await storeCurrentUserToken(communityIds: communities);
      }
    });
  }

  // Add SharedPreferences import at top
  // import 'package:shared_preferences/shared_preferences.dart';
}