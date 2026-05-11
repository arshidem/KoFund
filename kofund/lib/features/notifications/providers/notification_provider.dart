import 'dart:async';
import '../models/notification_model.dart';
import 'package:kofund/core/services/notification_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/services/fcm_token_service.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationStorageService _storage = NotificationStorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<AppNotification> _notifications = [];
  List<AppNotification> _filteredNotifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasError = false;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription? _userCommunitiesSubscription;
  
  // ⭐ NEW: Current filter state
  String? _currentCommunityFilter;
  NotificationType? _currentTeventTypeFilter;
  bool _showUnreadOnly = false;
  
  // ⭐ NEW: User communities for filtering
  List<String> _userCommunities = [];
  
  // ⭐ NEW: Reference to notification services
  late NotificationService _notificationService;
  late FCMTokenService _tokenService;

  List<AppNotification> get notifications => _filteredNotifications.isNotEmpty ? _filteredNotifications : _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  
  // ⭐ NEW: Getters for filter state
  String? get currentCommunityFilter => _currentCommunityFilter;
  NotificationType? get currentTeventTypeFilter => _currentTeventTypeFilter;
  bool get showUnreadOnly => _showUnreadOnly;
  List<String> get userCommunities => _userCommunities;

  NotificationProvider() {
    _setupAuthListener();
  }

  // ⭐ NEW: Initialize with services
  void initializeServices({
    required NotificationService notificationService,
    required FCMTokenService tokenService,
  }) {
    _notificationService = notificationService;
    _tokenService = tokenService;
    
    // Register action callbacks
    _notificationService.onApproveUser = (data) async {
      final userId = data['pendingUserId'] ?? data['userId']; // ✅ Prioritize pendingUserId
      if (userId == null) return;
      
      final currentUserName = _auth.currentUser?.displayName;
      await UserService().approveUser(userId, adminName: currentUserName);
      refresh();
    };
    
    _notificationService.onRejectUser = (data) async {
      final userId = data['pendingUserId'] ?? data['userId']; // ✅ Prioritize pendingUserId
      final communityId = data['communityId'];
      if (userId == null || communityId == null) return;
      await UserService().rejectUser(userId, communityId);
      refresh();
    };

    debugPrint('✅ NotificationProvider services initialized and callbacks registered');
  }

  // ⭐ UPDATED: Listen to auth changes
  void _setupAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      debugPrint('🔄 Auth state changed: ${user?.uid ?? "logged out"}');
      
      if (user != null) {
        _loadUserCommunities();
        _loadNotifications();
        _loadUnreadCount();
      } else {
        _clearUserData();
      }
    });
  }

  // ⭐ NEW: Load user's communities for filtering
  Future<void> _loadUserCommunities() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('cached_notification_communities');
      
      if (cached != null && cached.isNotEmpty) {
        _userCommunities = cached;
        debugPrint('🏘️ Loaded user communities from cache: ${_userCommunities.join(', ')}');
        _applyFilters();
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          _userCommunities = (data?['notificationCommunities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [];
          
          await prefs.setStringList('cached_notification_communities', _userCommunities);
          debugPrint('🏘️ Loaded user communities from Firestore and cached: ${_userCommunities.join(', ')}');
        }

        // ⭐ NEW: Subscribe to user communities changes
        _userCommunitiesSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
              if (snapshot.exists) {
                final updatedCommunities = (snapshot.data()?['notificationCommunities'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ?? [];
                
                if (!listEquals(_userCommunities, updatedCommunities)) {
                  _userCommunities = updatedCommunities;
                  debugPrint('🔄 User communities updated: ${_userCommunities.join(', ')}');
                  _applyFilters(); // Reapply filters with new communities
                }
              }
            });
      }
    } catch (e) {
      debugPrint('❌ Error loading user communities: $e');
    }
  }

  // Clear data when user logs out
  void _clearUserData() {
    _notificationSubscription?.cancel();
    _userCommunitiesSubscription?.cancel();
    _notifications.clear();
    _filteredNotifications.clear();
    _unreadCount = 0;
    _userCommunities.clear();
    _currentCommunityFilter = null;
    _currentTeventTypeFilter = null;
    _showUnreadOnly = false;
    _isLoading = false;
    _hasError = false;
    notifyListeners();
    
    // ⭐ NEW: Call storage cleanup
    _storage.cleanupForUserLogout();
  }

  // ⭐ UPDATED: Load notifications with filter support
  Future<void> _loadNotifications() async {
    // Cancel previous subscription
    _notificationSubscription?.cancel();
    
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user for notifications');
        _notifications.clear();
        _filteredNotifications.clear();
        _isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint('📥 Loading notifications for user: ${user.uid}');
      
      // ⭐ UPDATED: Use filtered stream if filters are active
      Stream<List<AppNotification>> notificationStream;
      if (_currentCommunityFilter != null || _currentTeventTypeFilter != null) {
        notificationStream = _storage.getNotificationsStream(
          filterByCommunity: _currentCommunityFilter,
          filterByType: _currentTeventTypeFilter,
        );
        debugPrint('🎯 Using filtered stream - Community: $_currentCommunityFilter, type: $_currentTeventTypeFilter');
      } else {
        notificationStream = _storage.getNotificationsStream();
      }
      
      // Subscribe to user-specific notifications
      _notificationSubscription = notificationStream.listen(
        (notifications) {
          debugPrint('📥 Received ${notifications.length} notifications');
          
          // Filter only notifications for current user (extra safety)
          final filteredNotifications = notifications.where((n) => n.userId == user.uid).toList();
          
          if (filteredNotifications.length != notifications.length) {
            debugPrint('⚠️ Filtered out ${notifications.length - filteredNotifications.length} notifications not for current user!');
          }
          
          _notifications = filteredNotifications;
          
          // ⭐ NEW: Apply additional filters (unread only)
          _applyFilters();
          
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('❌ Notification stream error: $error');
          _isLoading = false;
          _hasError = true;
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  // ⭐ NEW: Apply filters to notifications
  void _applyFilters() {
    List<AppNotification> filtered = List.from(_notifications);
    
    // Apply unread filter
    if (_showUnreadOnly) {
      filtered = filtered.where((n) => !n.isRead).toList();
    }
    
    _filteredNotifications = filtered;
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  Future<void> _loadUnreadCount() async {
    try {
      // ⭐ UPDATED: Get unread count for current community if filtered
      if (_currentCommunityFilter != null) {
        _unreadCount = await _storage.getUnreadCountByCommunity(_currentCommunityFilter!);
      } else {
        _unreadCount = await _storage.getUnreadCount();
      }
      debugPrint('📊 Unread count: $_unreadCount');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading unread count: $e');
    }
  }

  // ⭐ NEW: Filter notifications by community
  Future<void> filterByCommunity(String? communityId) async {
    _currentCommunityFilter = communityId;
    _currentTeventTypeFilter = null; // Reset type filter when changing community
    await _loadNotifications();
    await _loadUnreadCount();
    
    if (communityId != null) {
      debugPrint('🏘️ Filtering notifications by community: $communityId');
    } else {
      debugPrint('🏘️ Clearing community filter');
    }
  }

  // ⭐ NEW: Filter notifications by type
  Future<void> filterByType(NotificationType? type) async {
    _currentTeventTypeFilter = type;
    await _loadNotifications();
    
    if (type != null) {
      debugPrint('🎯 Filtering notifications by type: ${type.name}');
    } else {
      debugPrint('🎯 Clearing type filter');
    }
  }

  // ⭐ NEW: Toggle unread filter
  void toggleUnreadFilter() {
    _showUnreadOnly = !_showUnreadOnly;
    _applyFilters();
    notifyListeners();
    debugPrint('👁️ Toggle unread filter: $_showUnreadOnly');
  }

  // ⭐ NEW: Clear all filters
  void clearFilters() {
    _currentCommunityFilter = null;
    _currentTeventTypeFilter = null;
    _showUnreadOnly = false;
    _filteredNotifications.clear();
    _loadNotifications();
    _loadUnreadCount();
    debugPrint('🧹 Cleared all filters');
  }

  // ⭐ UPDATED: Mark as read with validation
  Future<void> markAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // ⭐ NEW: Find notification first
      final notification = _notifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => AppNotification(
          id: '',
          eventId: '',
          title: '',
          body: '',
          type: NotificationType.announcement,
          timestamp: DateTime.now(),
        ),
      );
      
      // Check if notification belongs to current user
      if (notification.userId != user.uid) {
        debugPrint('⚠️ Cannot mark notification as read - belongs to different user');
        return;
      }
      
      await _storage.markAsRead(notificationId);
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _applyFilters(); // Reapply filters
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error marking as read: $e');
    }
  }

  // ⭐ UPDATED: Mark all as read with filter support
  Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // ⭐ NEW: Mark all in current filter context
      if (_currentCommunityFilter != null) {
        // Mark all in current community as read
        final communityNotifications = _notifications
            .where((n) => n.communityId == _currentCommunityFilter && !n.isRead)
            .toList();
        
        for (final notification in communityNotifications) {
          await _storage.markAsRead(notification.id);
        }
      } else {
        // Mark all notifications as read
        await _storage.markAllAsRead();
      }
      
      // Update all to read locally
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _applyFilters(); // Reapply filters
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _storage.deleteNotification(notificationId);
      _notifications.removeWhere((n) => n.id == notificationId);
      _applyFilters(); // Reapply filters
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error deleteing notification: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _storage.clearAllNotifications();
      _notifications.clear();
      _filteredNotifications.clear();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing all: $e');
    }
  }

  void refresh() {
    _loadUserCommunities();
    _loadNotifications();
    _loadUnreadCount();
  }

  // ⭐ UPDATED: Add local notification with community validation
  void addLocalNotification(AppNotification notification) {
    final user = _auth.currentUser;
    if (user == null || notification.userId != user.uid) {
      debugPrint('⚠️ Cannot add notification for different user');
      return;
    }
    
    // ⭐ NEW: Check if user belongs to notification community
    if (notification.communityId != null && 
        notification.communityId!.isNotEmpty &&
        !_userCommunities.contains(notification.communityId)) {
      debugPrint('⚠️ User not in notification community: ${notification.communityId}');
      return;
    }
    
    _notifications.insert(0, notification);
    _applyFilters(); // Reapply filters
    notifyListeners();
  }

  // ⭐ NEW: Get notifications by community
  List<AppNotification> getNotificationsByCommunity(String communityId) {
    return _notifications
        .where((n) => n.communityId == communityId)
        .toList();
  }

  // ⭐ NEW: Get unread count by community
  int getUnreadCountByCommunity(String communityId) {
    return _notifications
        .where((n) => n.communityId == communityId && !n.isRead)
        .length;
  }

  // Filter notifications
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
      
  List<AppNotification> get readNotifications =>
      _notifications.where((n) => n.isRead).toList();
      
  List<AppNotification> get highPriorityNotifications =>
      _notifications.where((n) => n.isHighPriority).toList();
  
  // ⭐ NEW: Get community notifications
  Map<String, List<AppNotification>> get notificationsByCommunity {
    final map = <String, List<AppNotification>>{};
    
    for (final notification in _notifications) {
      final communityId = notification.communityId ?? 'global';
      if (!map.containsKey(communityId)) {
        map[communityId] = [];
      }
      map[communityId]!.add(notification);
    }
    
    return map;
  }

  // 🆕 NEW: Debug function
  Future<void> debugNotifications() async {
    await _storage.debugUserNotifications();
  }

  // ⭐ NEW: Send community notification
  Future<void> sendCommunityNotification({
    required String communityId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic> data = const {},
    String? eventId,
    String? senderName,
  }) async {
    try {
      await _notificationService.sendCommunityNotification(
        communityId: communityId,
        title: title,
        body: body,
        type: type,
        data: data,
        eventId: eventId,
        senderName: senderName,
      );
      debugPrint('✅ Community notification sent');
    } catch (e) {
      debugPrint('❌ Error sending community notification: $e');
    }
  }

  // ⭐ NEW: Update user's communities
  Future<void> updateUserCommunities(List<String> communityIds) async {
    try {
      await _storage.updateNotificationCommunities(communityIds);
      await _notificationService.updateUserCommunities(communityIds);
      _userCommunities = communityIds;
      debugPrint('✅ Updated user communities: ${communityIds.join(', ')}');
    } catch (e) {
      debugPrint('❌ Error updating user communities: $e');
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _authSubscription?.cancel();
    _userCommunitiesSubscription?.cancel();
    super.dispose();
  }
}





