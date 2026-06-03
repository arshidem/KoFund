import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kofund/features/notifications/models/notification_model.dart';
import './notification_storage_service.dart';
import './fcm_token_service.dart';

import 'package:kofund/core/utils/notification_channels.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:kofund/routing/go_router_config.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/main.dart' show navigatorKey;


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late NotificationStorageService _storage;
  late FCMTokenService _tokenService;

  // ⭐ NEW: Callbacks for notification actions to avoid circular dependencies
  Future<void> Function(Map<String, dynamic>)? onApproveUser;
  Future<void> Function(Map<String, dynamic>)? onRejectUser;

  // ⭐ NEW: Store notification preferences
  static const String _notificationPrefsKey = 'notification_settings';
  
  // ⭐ NEW: Background handler with community validation
@pragma('vm:entry-point')
static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Handling background message");
  
  await Firebase.initializeApp();
  
  try {
    final data = message.data;
    final notification = message.notification;
    
    final now = DateTime.now();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // ⭐ NEW: Validate if notification is for current user's communities
    final notificationCommunityId = data['communityId'];
    
    // If notification has community ID, we need to validate
    if (notificationCommunityId != null) {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('current_notification_user_id');
      
      // Check if notification is for current user
      if (storedUserId != currentUserId) {
        debugPrint("⚠️ Background: User ID mismatch. Stored: $storedUserId, Current: $currentUserId");
        debugPrint("   🔕 Filtering notification for different user");
        return; // Don't show notification for different user
      }
      
      // 🚀 OPTIMIZATION: Check local cache first
      final cachedCommunities = prefs.getStringList('cached_notification_communities') ?? [];
      
      if (cachedCommunities.isNotEmpty) {
        if (!cachedCommunities.contains(notificationCommunityId)) {
          debugPrint("⚠️ Background: User not in cached notification community");
          return;
        }
      } else if (currentUserId != null) {
        // Fallback to Firestore only if cache is empty
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
            
        final userCommunities = (userDoc.data()?['notificationCommunities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
            
        if (!userCommunities.contains(notificationCommunityId)) {
          debugPrint("⚠️ Background: User not in notification community (Firestore fallback)");
          return; // Don't show notification
        }
      }
    }
    
    // 🆕 Use notificationId from data if available (from Cloud Function)
    final String baseId = data['notificationId'] ?? 
                          '${now.millisecondsSinceEpoch}_bg_${currentUserId ?? 'anonymous'}';
    
    // Ensure ID consistency with foreground: baseId_userId
    final notificationId = (currentUserId != null && !baseId.contains('_$currentUserId'))
        ? '${baseId}_$currentUserId'
        : baseId;
    
    // 🆕 Check if this is from Cloud Function (has sentFromApp flag)
    final isFromCloudFunction = data['sentFromApp'] == 'true' || 
                               data['sentFromApp'] == true;
    
    if (isFromCloudFunction) {
      debugPrint("📦 Background message is from Cloud Function, ID: $notificationId");
      
      // ⭐ CRITICAL: DO NOT save to Firestore - Cloud Function already did!
      // Only show local notification
    }

    final appNotification = AppNotification(
      id: notificationId,
      title: notification?.title ?? data['title'] ?? 'New Notification',
      body: notification?.body ?? data['body'] ?? '',
      type: _parseNotificationTypeFromString(data['type']),
      priority: _parsePriorityFromString(data['priority']),
      data: data,
      userId: currentUserId,
      eventId: data['eventId'],
      communityId: data['communityId'],
      isRead: false,
      timestamp: now,
      deepLink: data['deepLink'],
      senderName: data['senderName'],
      imageUrl: data['imageUrl'],
    );

    // ⭐ REMOVED: Firestore saving logic here
    // Cloud Function already saved the notification

    // Show local notification with actions in background
    final List<AndroidNotificationAction> actions = [];
    final type = _parseNotificationTypeFromString(data['type']);
    final eventId = data['eventId'];

    if (type == NotificationType.pendingUser) {
      actions.add(const AndroidNotificationAction('approve_user', 'Approve', showsUserInterface: true, cancelNotification: true));
      actions.add(const AndroidNotificationAction('reject_user', 'Reject', showsUserInterface: true, cancelNotification: true));
    }
    
    if ((type == NotificationType.announcement || type == NotificationType.event) && eventId != null) {
      actions.add(const AndroidNotificationAction('join_event', 'Join event 🎯', showsUserInterface: true, cancelNotification: true));
    }

    final channelId = NotificationChannels.getChannelId(type);
    final channelName = NotificationChannels.getChannelName(type);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelName,
      importance: Importance.max,
      priority: Priority.high,
      actions: actions,
      styleInformation: BigTextStyleInformation(appNotification.body),
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications.show(
      appNotification.hashCode,
      appNotification.title,
      appNotification.body,
      details,
      payload: jsonEncode({
        ...data,
        'id': notificationId,
      }),
    );
    
    debugPrint("✅ Background notification handled");
  } catch (e) {
    debugPrint("❌ Background handler error: $e");
  }
}

  static NotificationType _parseNotificationTypeFromString(String? type) {
    if (type == null) return NotificationType.announcement;
    String typeStr = type.contains('.') ? type.split('.').last : type;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      );
    } catch (_) {
      return NotificationType.announcement;
    }
  }

  static NotificationPriority _parsePriorityFromString(String? priority) {
    if (priority == null) return NotificationPriority.normal;
    try {
      return NotificationPriority.values.firstWhere(
        (e) => e.name == priority.toLowerCase(),
      );
    } catch (_) {
      return NotificationPriority.normal;
    }
  }

Future<void> init({
  required NotificationStorageService storage,
  required FCMTokenService tokenService,
}) async {
  try {
    debugPrint("🔄 Starting NotificationService initialization...");
    
    _storage = storage;
    _tokenService = tokenService;

    // Initialize storage FIRST (works offline)
    await _storage.init();
    debugPrint("✅ Storage initialized");

    // Try to initialize local notifications (works offline)
    await _initLocalNotifications();
    debugPrint("✅ Local notifications initialized");
    
    // Try to request permissions (silently fails if offline)
    await _requestNotificationPermissions();
    
    // Setup FCM in background without blocking
    _setupFCMInBackground();
    
    debugPrint("✅ NotificationService initialized successfully");
  } catch (e) {
    debugPrint("⚠️ NotificationService init error (non-critical): $e");
  }
}

// ⭐ UPDATED: Setup FCM with community validation
void _setupFCMInBackground() {
  Future.microtask(() async {
    try {
      await _configureFCM();
      debugPrint("✅ FCM configured");
      
      // ⭐ NEW: Get current user's communities before storing token
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final communities = (userDoc.data()?['notificationCommunities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        
        // ⭐ UPDATED: Store token with community context
        await _tokenService.storeCurrentUserToken(communityIds: communities);
        
        // 🚀 OPTIMIZATION: Cache communities for background/permission checks
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_notification_communities', communities);
      }
      
      _tokenService.setupTokenRefreshListener();
      
      final token = await getFCMToken();
      debugPrint("📨 FCM Token: ${token?.substring(0, 20)}...");
    } catch (e) {
      debugPrint("⚠️ FCM setup failed (will retry): $e");
      // Schedule retry
      _scheduleFCMRetry();
    }
  });
}

  // Retry FCM setup if it failed
  void _scheduleFCMRetry() {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        await _configureFCM();
final user = _auth.currentUser;
if (user != null) {
  final userDoc = await _firestore.collection('users').doc(user.uid).get();
  final communities = (userDoc.data()?['notificationCommunities'] as List<dynamic>?)
      ?.map((e) => e.toString())
      .toList() ?? [];
  
  await _tokenService.storeCurrentUserToken(communityIds: communities);
}        debugPrint("✅ FCM setup successful on retry");
        timer.cancel();
      } catch (e) {
        // Keep retrying
      }
    });
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint("🔔 Permission status: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint("✅ User granted notification permission");
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint("⚠️ User granted provisional permission");
      } else {
        debugPrint("❌ User denied or hasn't accepted permission");
      }
    } catch (e) {
      debugPrint("❌ Error requesting permissions: $e");
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await NotificationChannels.createAllChannels(_localNotifications);
  }

// ⭐ UPDATED: Configure FCM with community filtering
Future<void> _configureFCM() async {
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    String? token = await _messaging.getToken();
    debugPrint("📨 FCM Token: $token");
    
    // ⭐ UPDATED: Foreground message handler with validation
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("📩 Foreground Message: ${message.notification?.title}");
      
      // ⭐ NEW: Validate if notification is for current user
      final isValid = await _tokenService.isNotificationForCurrentUser(message.data);
      if (!isValid) {
        debugPrint("🔕 Filtered foreground notification (not for current user/community)");
        return;
      }
      
      await _handleForegroundMessage(message);
    });
    
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("🚀 App opened from terminated state");
      _handleNotificationMessage(initialMessage);
    }
    
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📌 App opened from background");
      _handleNotificationMessage(message);
    });
    
  } catch (e) {
    debugPrint("❌ Error configuring FCM: $e");
  }
}

// ⭐ UPDATED: Handle foreground message with community check
Future<void> _handleForegroundMessage(RemoteMessage message) async {
  try {
    final notification = _createNotificationFromMessage(message);
    
    // ⭐ NEW: Check if notification is from Cloud Function
    final isFromCloudFunction = message.data['sentFromApp'] == 'true' || 
                               message.data['sentFromApp'] == true;
    
    if (isFromCloudFunction) {
      debugPrint("📦 Foreground message is from Cloud Function, skipping Firestore save");
      // ⭐ Only show local notification, don't save to Firestore
      await _showLocalNotification(notification);
      return;
    }
    
    // ⭐ NEW: Check if notification is for current user
    final isForCurrentUser = await _tokenService.isNotificationForCurrentUser(message.data);
    if (!isForCurrentUser) {
      debugPrint("🔕 Filtered notification: Not for current user/community");
      return;
    }
    
    if (await _isNotificationTypeMuted(notification.type)) {
      debugPrint("🔇 Notification type muted: ${notification.type}");
      return;
    }

    // ⭐ ONLY save to Firestore if NOT from Cloud Function
    await _storage.saveNotification(notification);
    await _showLocalNotification(notification);
  } catch (e) {
    debugPrint("❌ Error handling foreground message: $e");
  }
}

  Future<void> _handleNotificationMessage(RemoteMessage message) async {
    try {
      final notification = _createNotificationFromMessage(message);
      debugPrint("🎯 Notification tapped: ${notification.title}");

      // Import the navigatorKey from main.dart to navigate without a context
      // Give the navigator a brief moment to be ready (cold start)
      await Future.delayed(const Duration(milliseconds: 500));

      final nav = navigatorKey.currentState;
      if (nav == null) {
        debugPrint("⚠️ Navigator not ready yet");
        return;
      }

      // Navigate using the same logic as local notification taps
      _navigateToDetailScreen(notification.data);
    } catch (e) {
      debugPrint("❌ Error handling notification message: $e");
    }
  }

AppNotification _createNotificationFromMessage(RemoteMessage message) {
  final data = message.data;
  final notification = message.notification;
  
  final now = DateTime.now();
  
  // Get userId from data or current user
  final userId = data['userId'] ?? _auth.currentUser?.uid;
  
  // Get base notificationId
  final String baseId = data['notificationId'] ?? '${now.millisecondsSinceEpoch}';
  
  // 🆕 Construct full ID: base_userId (SAME as Cloud Function)
  // Ensure we don't double-append userId if it's already there
  final notificationId = baseId.contains('_$userId') ? baseId : '${baseId}_$userId';
  
  debugPrint("📝 Created notification ID: $notificationId (base: $baseId, userId: $userId)");
  
  return AppNotification(
    id: notificationId,
    title: notification?.title ?? data['title'] ?? 'New Notification',
    body: notification?.body ?? data['body'] ?? '',
    type: _parseNotificationType(data['type']),
    priority: _parsePriority(data['priority']),
    data: data,
    userId: userId,
    eventId: data['eventId'],
    communityId: data['communityId'],
    isRead: false,
    timestamp: now,
    deepLink: data['deepLink'],
    senderName: data['senderName'],
    imageUrl: data['imageUrl'],
  );
  
  // ⭐ NO MORE Firestore saving here - Cloud Function already saved it!
}

  NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.announcement;
    // Handle both "announcement" and "NotificationType.announcement"
    String typeStr = type.contains('.') ? type.split('.').last : type;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      );
    } catch (_) {
      return NotificationType.announcement;
    }
  }

  NotificationPriority _parsePriority(String? priority) {
    if (priority == null) return NotificationPriority.normal;
    try {
      return NotificationPriority.values.firstWhere(
        (e) => e.name == priority.toLowerCase(),
      );
    } catch (_) {
      return NotificationPriority.normal;
    }
  }

// ⭐ UPDATED: Mute by community
Future<bool> _isNotificationTypeMuted(NotificationType type) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Check global mute for type
  final globalKey = 'notification_${type.name}';
  if (prefs.getBool(globalKey) == true) {
    return true;
  }
  
  // Check if community notifications are muted
  final communityMuteKey = 'notification_muted_communities';
  final mutedCommunities = prefs.getStringList(communityMuteKey) ?? [];
  
  return false;
}

  Future<void> _showLocalNotification(AppNotification notification) async {
    try {
      final List<AndroidNotificationAction> actions = [];
      if (notification.type == NotificationType.pendingUser) {
        actions.add(const AndroidNotificationAction(
          'approve_user',
          'Approve',
          showsUserInterface: true,
          cancelNotification: true,
        ));
        actions.add(const AndroidNotificationAction(
          'reject_user',
          'Reject',
          showsUserInterface: true,
          cancelNotification: true,
        ));
      }

      // Add Join action for event announcements
      if ((notification.type == NotificationType.announcement || 
           notification.type == NotificationType.event) && 
          (notification.id != null || notification.data['eventId'] != null)) {
        actions.add(const AndroidNotificationAction(
          'join_event',
          'Join event 🎯',
          showsUserInterface: true,
          cancelNotification: true,
        ));
      }

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationChannels.getChannelId(notification.type),
            NotificationChannels.getChannelName(notification.type),
            channelDescription: NotificationChannels.getChannelName(notification.type),
            importance: Importance.high,
            priority: Priority.high,
            color: notification.priorityColor,
            styleInformation: BigTextStyleInformation(
              notification.body,
              htmlFormatBigText: true,
              contentTitle: notification.title,
              htmlFormatContentTitle: true,
            ),
            autoCancel: true,
            showWhen: true,
            enableLights: true,
            enableVibration: true,
            actions: actions,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: notification.type == NotificationType.pendingUser ? 'pending_user_actions' : null,
          ),
        ),
        payload: jsonEncode({
          'notificationId': notification.id,
          'type': notification.type.name,
          'deepLink': notification.deepLink,
          'userId': notification.data['userId'], // Target user ID for actions
          'communityId': notification.data['communityId'],
          ...notification.data,
        }),
      );

      debugPrint("📱 Local notification shown: ${notification.title}");
    } catch (e) {
      debugPrint("❌ Error showing local notification: $e");
    }
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint("🎯 Notification response received: ${response.actionId}");
    try {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        
        // Handle Action Buttons
        if (response.actionId == 'approve_user') {
          _handleActionApproveUser(data);
          return;
        } else if (response.actionId == 'reject_user') {
          _handleActionRejectUser(data);
          return;
        } else if (response.actionId == 'join_event') {
          // Open detail screen first
          _navigateToDetailScreen(data);
          return;
        }

        // Standard notification tap
        if (data['notificationId'] != null) {
          _storage.markAsRead(data['notificationId']);
        }
        
        // Navigate to details
        _navigateToDetailScreen(data);
      }
    } catch (e) {
      debugPrint("❌ Error processing notification response: $e");
    }
  }

  void handleNotificationTap(AppNotification notification) {
    _navigateToDetailScreen({
      ...notification.data,
      'id': notification.id,
      'title': notification.title,
      'body': notification.body,
      'eventId': notification.eventId,
      'recipientId': notification.userId, // ✅ Avoid overwriting 'userId' in data
    });
  }

  void _navigateToDetailScreen(Map<String, dynamic> data) async {
    // Wait for navigator to be ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    final context = GoRouterConfig.rootNavigatorKey.currentContext;
    if (context == null) return;

    final eventId = data['eventId'];
    if (eventId != null && eventId.toString().isNotEmpty) {
      debugPrint("🚀 Navigating directly to event Details: $eventId");
      context.push('${RouteNames.eventDetails}/${eventId.toString()}');
      return;
    }

    // Create AppNotification from data
    final notification = _createNotificationFromData(data);
    
    context.push(RouteNames.notificationDetail, extra: notification);
  }

  AppNotification _createNotificationFromData(Map<String, dynamic> data) {
    final now = DateTime.now();
    // ✅ Check recipientId first, then userId, to correctly set the owner without losing original data
    final ownerId = data['recipientId'] ?? data['userId'] ?? _auth.currentUser?.uid;
    final String baseId = data['notificationId'] ?? '${now.millisecondsSinceEpoch}';
    final notificationId = (data['id'] != null) 
        ? data['id'].toString() 
        : (baseId.contains('_$ownerId') ? baseId : '${baseId}_$ownerId');

    return AppNotification(
      id: notificationId,
      title: data['title'] ?? 'New Notification',
      body: data['body'] ?? '',
      type: _parseNotificationType(data['type']),
      priority: _parsePriority(data['priority']),
      data: data,
      userId: ownerId,
      eventId: data['eventId'],
      communityId: data['communityId'],
      isRead: false,
      timestamp: now,
      deepLink: data['deepLink'],
      senderName: data['senderName'],
      imageUrl: data['imageUrl'],
    );
  }

  // Action Handlers (Forward to injected callbacks)
  Future<void> _handleActionApproveUser(Map<String, dynamic> data) async {
    if (onApproveUser != null) {
      debugPrint("✅ Executing injected Approve callback");
      await onApproveUser!(data);
    } else {
      debugPrint("⚠️ No Approve callback registered in NotificationService");
    }
  }

  Future<void> _handleActionRejectUser(Map<String, dynamic> data) async {
    if (onRejectUser != null) {
      debugPrint("❌ Executing injected Reject callback");
      await onRejectUser!(data);
    } else {
      debugPrint("⚠️ No Reject callback registered in NotificationService");
    }
  }

@pragma('vm:entry-point')
static void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background action if needed
  debugPrint("🎯 Background notification tap: ${notificationResponse.actionId}");
}

  // Public API
  Future<String?> getFCMToken() => _messaging.getToken();
  
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint("✅ Subscribed to topic: $topic");
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint("✅ Unsubscribed from topic: $topic");
  }

  // ⭐ NEW: Update user's communities (call when user joins/leaves)
  Future<void> updateUserCommunities(List<String> communityIds) async {
    try {
      await _tokenService.updateUserCommunities(communityIds);
      debugPrint("✅ Updated user communities for notifications: ${communityIds.join(', ')}");
    } catch (e) {
      debugPrint("❌ Error updating user communities: $e");
    }
  }

  // ⭐ NEW: Handle user logout
  Future<void> handleUserLogout() async {
    try {
      await _tokenService.handleUserLogout();
      debugPrint("✅ Notification service cleaned up for logout");
    } catch (e) {
      debugPrint("❌ Error handling logout in notification service: $e");
    }
  }

// ⭐ UPDATED: MAIN COMMUNITY NOTIFICATION METHOD WITH VALIDATION
Future<void> sendCommunityNotification({
  required String communityId,
  required String title,
  required String body,
  required NotificationType type,
  Map<String, dynamic> data = const {},
  String? eventId,
  String? senderName,
  bool skipPush = false, // 🆕 NEW: Option to skip push notification
  String? targetRole, // 🆕 NEW: Filter by role (e.g., 'admin')
}) async {
  try {
    debugPrint("📢 Calling Cloud Function: sendCommunityNotification (skipPush: $skipPush)");
    
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("❌ User not authenticated");
      return;
    }
    
    // ⭐ UPDATED: Validate sender belongs to community (Check primary communityId AND notificationCommunities)
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data() ?? {};
    final userPrimaryCommunityId = userData['communityId'] as String?;
    final userNotificationCommunities = (userData['notificationCommunities'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    
    final isAuthorized = type == NotificationType.pendingUser ||
                         userPrimaryCommunityId == communityId || 
                         userNotificationCommunities.contains(communityId);
                         
    if (!isAuthorized) {
      debugPrint("❌ User not authorized for community notification: $communityId");
      debugPrint("   User Primary Community: $userPrimaryCommunityId");
      debugPrint("   User Notification Communities: ${userNotificationCommunities.join(', ')}");
      return;
    }
    
    debugPrint("✅ Sender authorized for community $communityId (via ${userPrimaryCommunityId == communityId ? 'Primary ID' : 'Notification List'})");
    
    final currentUserName = currentUser.displayName ?? 'User';
    
    // 🆕 Generate base notification ID
    final now = DateTime.now();
    final baseNotificationId = '${now.millisecondsSinceEpoch}';
    
    final callData = {
      'communityId': communityId,
      'title': title,
      'body': body,
      'type': type.name,
      'eventId': eventId,
      'senderName': senderName ?? currentUserName,
      'senderId': currentUser.uid, // ⭐ ADD: For validation in Cloud Function
      'skipPush': skipPush, // 🆕 PASS SKIP PUSH FLAG
      'targetRole': targetRole, // 🆕 PASS TARGET ROLE
      'data': {
        ...data,
        'senderId': currentUser.uid,
        'sentFromApp': true,
        'appVersion': '2.0.0',
        'notificationId': baseNotificationId, // 🆕 PASS BASE ID
      },
    };
    
    debugPrint("📦 Call data: ${jsonEncode(callData)}");
    
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    
    final callable = functions.httpsCallable(
      'sendCommunityNotification',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 30),
      ),
    );
    
    final result = await callable.call(callData);
    
    final resultData = result.data as Map<String, dynamic>;
    debugPrint("✅ Cloud Function Result: $resultData");
    
    if (resultData['success'] == true) {
      debugPrint("✅ Notification sent successfully via Cloud Function");
    } else {
      debugPrint("⚠️ Cloud Function returned: ${resultData['message']}");
      throw Exception(resultData['message']);
    }
    
  } on FirebaseFunctionsException catch (e) {
    debugPrint("❌ Functions Error: ${e.code} - ${e.message}");
    debugPrint("📌 Details: ${e.details}");
    
    // Fallback to local method
    await _sendCommunityNotificationLocalFallback(
      communityId: communityId,
      title: title,
      body: body,
      type: type,
      data: data,
      eventId: eventId,
      senderName: senderName,
      targetRole: targetRole,
    );
  } catch (e, stackTrace) {
    debugPrint("❌ Error calling Cloud Function: $e");
    debugPrint("📌 Stack trace: $stackTrace");
  }
}

// ⭐ UPDATED: Fallback method (Robust version)
Future<void> _sendCommunityNotificationLocalFallback({
  required String communityId,
  required String title,
  required String body,
  required NotificationType type,
  Map<String, dynamic> data = const {},
  String? eventId,
  String? senderName,
  String? targetRole,
}) async {
  try {
    debugPrint("🔄 [Fallback] Starting robust delivery to community: $communityId");
    
    // 1. Get all members of this community
    final usersSnapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .get();
        
    debugPrint("👥 [Fallback] Found ${usersSnapshot.docs.length} community members");
    
    if (usersSnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    final now = DateTime.now();
    final baseNotificationId = '${now.millisecondsSinceEpoch}';
    int notificationsCreated = 0;

    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      if (userData['isVirtualUser'] == true) continue;
      
      // Filter by role if specified
      if (targetRole != null && userData['role'] != targetRole) continue;
      
      final userId = userDoc.id;
      final notificationId = '${baseNotificationId}_$userId';
      
      final notification = AppNotification(
        id: notificationId,
        title: title,
        body: body,
        type: type,
        priority: NotificationPriority.high,
        data: { ...data, 'communityId': communityId },
        userId: userId,
        communityId: communityId,
        eventId: eventId,
        isRead: false,
        timestamp: now,
        senderName: senderName ?? 'KoFund Admin',
      );

      final notificationRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId);
      
      batch.set(notificationRef, notification.toFirestore());
      notificationsCreated++;

      // Show local notification only if this is the current active user
      if (_auth.currentUser?.uid == userId) {
        await _showLocalNotification(notification);
      }
    }
    
    await batch.commit();
    debugPrint("✅ [Fallback] Successfully saved $notificationsCreated notifications to community member records");
    
  } catch (e) {
    debugPrint("❌ [Fallback] Error: $e");
  }
}

// ⭐ UPDATED: User notification with validation
Future<void> sendUserNotification({
  required String userId,
  required String title,
  required String body,
  required NotificationType type,
  Map<String, dynamic> data = const {},
  String? eventId,
  String? communityId,
  String? senderName,
}) async {
  try {
    debugPrint("📨 Sending user notification via Cloud Function");
    
    // ✅ Check if target user is virtual to avoid unnecessary DB saves and push notifications
    final targetDoc = await _firestore.collection('users').doc(userId).get();
    if (targetDoc.exists && targetDoc.data()?['isVirtualUser'] == true) {
      debugPrint("🔕 Skipping notification: Target $userId is a virtual user");
      return;
    }
    
    // ⭐ NEW: Validate sender has permission to send to this user
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("❌ User not authenticated");
      return;
    }
    
    // Check if sender and receiver are in same community
    if (communityId != null) {
      final senderDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final senderData = senderDoc.data() ?? {};
      final senderPrimaryCommunity = senderData['communityId'] as String?;
      final senderNotifCommunities = (senderData['notificationCommunities'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      
      // ✅ Check BOTH primary communityId AND notificationCommunities list
      final isAuthorized = senderPrimaryCommunity == communityId ||
                           senderNotifCommunities.contains(communityId);
      
      if (!isAuthorized) {
        debugPrint("❌ Sender not authorized for community $communityId");
        debugPrint("   Primary: $senderPrimaryCommunity, List: ${senderNotifCommunities.join(', ')}");
        return;
      }
    }
    
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final callable = functions.httpsCallable('sendUserNotification');
    
    // Create the SAME notification ID that Cloud Function will use
    final now = DateTime.now();
    final baseId = now.millisecondsSinceEpoch.toString();
    final notificationId = '${baseId}_$userId';
    
    final callData = {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'senderId': currentUser.uid,
      'senderName': senderName, // ⭐ MOVE TO ROOT: Required by Cloud Function
      'data': {
        ...data,
        'eventId': eventId,
        'communityId': communityId,
        'senderName': senderName, // Keep in data too for local parsing
        'notificationId': baseId, // ⭐ Passing ONLY baseId to avoid double-appending
      },
    };
    
    final result = await callable.call(callData);
    final resultData = result.data as Map<String, dynamic>;
    
    debugPrint("✅ User notification sent: $resultData");
    
  } on FirebaseFunctionsException catch (e) {
    debugPrint("❌ Cloud Function error: ${e.code} - ${e.message}");
    // Fallback to local only
    await _sendLocalUserNotificationFallback(
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
      eventId: eventId,
      communityId: communityId,
      senderName: senderName,
    );
  } catch (e) {
    debugPrint("❌ Error sending user notification: $e");
  }
}

  // Fallback for user notification
  Future<void> _sendLocalUserNotificationFallback({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic> data = const {},
    String? eventId,
    String? communityId,
    String? senderName,
  }) async {
    try {
      final now = DateTime.now();
      final notificationId = '${now.millisecondsSinceEpoch}_$userId';
      
      final notification = AppNotification(
        id: notificationId,
        title: title,
        body: body,
        type: type,
        priority: NotificationPriority.normal,
        data: data,
        userId: userId,
        communityId: communityId,
        eventId: eventId,
        isRead: false,
        timestamp: now,
        senderName: senderName,
      );
      
      final currentUser = _auth.currentUser;
      if (currentUser?.uid == userId) {
        await _storage.saveNotification(notification);
        await _showLocalNotification(notification);
        debugPrint("✅ Local fallback notification saved");
      }
      
    } catch (e) {
      debugPrint("❌ Local fallback error: $e");
    }
  }

  // ⭐ NEW: Mute/Unmute notifications for a community
  Future<void> setCommunityMuteStatus(String communityId, bool isMuted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notification_muted_communities';
      final mutedCommunities = prefs.getStringList(key) ?? [];
      
      if (isMuted) {
        if (!mutedCommunities.contains(communityId)) {
          mutedCommunities.add(communityId);
        }
      } else {
        mutedCommunities.remove(communityId);
      }
      
      await prefs.setStringList(key, mutedCommunities);
      debugPrint("${isMuted ? '🔇' : '🔔'} Community $communityId notifications ${isMuted ? 'muted' : 'unmuted'}");
    } catch (e) {
      debugPrint("❌ Error setting community mute status: $e");
    }
  }

  // ⭐ NEW: Check if community is muted
  Future<bool> isCommunityMuted(String communityId) async {
    final prefs = await SharedPreferences.getInstance();
    final mutedCommunities = prefs.getStringList('notification_muted_communities') ?? [];
    return mutedCommunities.contains(communityId);
  }
// Add this static method to NotificationService class
static Future<void> unlinkDeviceTokenFromUser() async {
  try {
    debugPrint("🔕 Unlinking device token from user...");
    
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final messaging = FirebaseMessaging.instance;
    
    if (user == null) {
      debugPrint("⚠️ No user to unlink from");
      return;
    }
    
    final token = await messaging.getToken();
    if (token == null) {
      debugPrint("⚠️ No FCM token to unlink");
      return;
    }
    
    // Remove token from user's document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
    
    // Mark token as inactive in token collection
    await FirebaseFirestore.instance
        .collection('user_notification_tokens')
        .doc(token)
        .update({
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'deactivatedReason': 'user_logout',
        });
    
    debugPrint("✅ Device token unlinked from user");
    
  } catch (e) {
    debugPrint("❌ Error unlinking device token: $e");
  }
}
  // ⭐ NEW: Get current user's notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final settings = <String, dynamic>{
      'mutedCommunities': prefs.getStringList('notification_muted_communities') ?? [],
      'globalEnabled': prefs.getBool('notifications_enabled') ?? true,
    };
    
    // Add mute status for each notification type
    for (final type in NotificationType.values) {
      settings['type_${type.name}'] = prefs.getBool('notification_${type.name}') ?? false;
    }
    
    return settings;
  }
}





