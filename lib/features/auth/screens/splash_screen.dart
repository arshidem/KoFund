// lib/features/auth/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/providers/app_auth_provider.dart' as app_auth;
import '../../../features/auth/screens/login_screen.dart';
import '../../../features/auth/screens/verification_pending_screen.dart';
import '../../../features/auth/screens/set_phone_screen.dart';
import '../../../features/community/screens/join_community_screen.dart';
import '../../../features/community/screens/community_dashboard.dart';
import '../../../features/community/screens/pending_approval_screen.dart';
import '../../../features/events/screens/event_details_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/fcm_token_service.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../core/widgets/animated_logo.dart';

void unawaited(Future<void> future) {}

class SplashScreen extends StatefulWidget {
  final String? deepLinkInviteCode;
  final String? deepLinkEventId;
  const SplashScreen({super.key, this.deepLinkInviteCode, this.deepLinkEventId});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitializing = true;
  String _status = '';
  String? _pendingInviteCode;
  String? _pendingEventId;

  @override
  void initState() {
    super.initState();
    // Configure system UI immediately to match splash aesthetic
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // For dark bg
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _handleInviteCode();
    _handleEventId();
    _startSplashTimer();
  }

  /// Handle invite code - just save it, don't navigate based on it
  Future<void> _handleInviteCode() async {
    debugPrint('🔄 Handling invite code...');

    // 1. Check if deep link provided invite code
    if (widget.deepLinkInviteCode != null &&
        widget.deepLinkInviteCode!.isNotEmpty) {
      _pendingInviteCode = widget.deepLinkInviteCode;
      debugPrint('📱 Received invite code from deep link: $_pendingInviteCode');

      // Save to persistent storage for later use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_invite_code', _pendingInviteCode!);
      debugPrint('💾 Saved invite code to storage for later use');
    } else {
      // 2. Check storage for existing pending invite (from previous sessions)
      final prefs = await SharedPreferences.getInstance();
      _pendingInviteCode = prefs.getString('pending_invite_code');
      if (_pendingInviteCode != null) {
        debugPrint(
          '📋 Found pending invite in storage from previous session: $_pendingInviteCode',
        );
      }
    }
  }

  /// Clear pending invite code from storage
  Future<void> _clearPendingInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_invite_code');
    _pendingInviteCode = null;
    debugPrint('🗑️ Cleared pending invite code from storage');
  }

  Future<void> _handleEventId() async {
    if (widget.deepLinkEventId != null && widget.deepLinkEventId!.isNotEmpty) {
      _pendingEventId = widget.deepLinkEventId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_event_id', _pendingEventId!);
      debugPrint('💾 Saved event ID to storage: $_pendingEventId');
    } else {
      final prefs = await SharedPreferences.getInstance();
      _pendingEventId = prefs.getString('pending_event_id');
      if (_pendingEventId != null) {
        debugPrint('📋 Found pending event in storage: $_pendingEventId');
      }
    }
  }

  /// Ensure splash shows for exactly 1 second to match logo shimmer
  void _startSplashTimer() {
    _initializeAppWithTimeout();
  }

  /// Initialize notification system ASYNCHRONOUSLY
  Future<void> _initializeNotificationSystemInBackground() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint("🔄 Background: Initializing notification system...");

      final tokenService = Provider.of<FCMTokenService>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );

      // Quick check: is user eligible? (non-blocking)
      try {
        final isEligible = await tokenService.isUserEligibleForNotifications();
        if (!isEligible) {
          debugPrint("⚠️ User not eligible for notifications");
          return;
        }
      } catch (e) {
        debugPrint("⚠️ Eligibility check failed: $e");
        return;
      }

      // Get user's communities from CACHE first
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedCommunities = prefs.getStringList('user_communities') ?? [];

        if (cachedCommunities.isNotEmpty) {
          debugPrint(
            "🏘️ Using cached communities: ${cachedCommunities.join(', ')}",
          );
          await tokenService.storeCurrentUserToken(
            communityIds: cachedCommunities,
          );
          notificationProvider.updateUserCommunities(cachedCommunities);
          return;
        }
      } catch (e) {
        debugPrint("⚠️ Cache read failed: $e");
      }

      // If no cache, try Firestore (with timeout)
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 2));

        if (!userDoc.exists) return;

        final userData = userDoc.data();
        final communities =
            (userData?['notificationCommunities'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // Cache for next time
        if (communities.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('user_communities', communities);
        }

        if (communities.isEmpty) {
          debugPrint("🏘️ User has no communities for notifications");
          await tokenService.storeCurrentUserToken(communityIds: []);
        } else {
          debugPrint(
            "🏘️ Initializing with communities: ${communities.join(', ')}",
          );
          await tokenService.storeCurrentUserToken(communityIds: communities);
        }

        notificationProvider.updateUserCommunities(communities);
      } on TimeoutException {
        debugPrint("⏱️ Notification initialization timed out (continuing)");
      } catch (e) {
        debugPrint("❌ Notification initialization failed: $e");
      }
    } catch (e) {
      debugPrint("❌ Background notification init error: $e");
    }
  }

  /// Main initialization with timeout
  Future<void> _initializeAppWithTimeout() async {
    try {
      _updateStatus('');

      final authProvider = Provider.of<app_auth.AppAuthProvider>(
        context,
        listen: false,
      );

      // ⭐ Start the 1.0-second animation timer (skip if deep link)
      final splashTimer = Future.delayed(
        Duration(milliseconds: widget.deepLinkEventId != null ? 0 : 1000),
      );

      // ⭐ WAIT for auth provider to be initialized
      debugPrint("⏳ Waiting for auth provider initialization...");
      await authProvider.waitForInitialization();
      debugPrint("✅ Auth provider initialized");

      // ⭐ Ensure we wait at least for the 1-second shimmer to finish
      await splashTimer;

      // Now perform navigation
      await _performInitialization(authProvider);
    } catch (e) {
      debugPrint("❌ Splash initialization error: $e");
      if (mounted) _navigateToLogin();
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _performInitialization(
    app_auth.AppAuthProvider authProvider,
  ) async {
    // Artificial delay removed as it's handled by the splashTimer in _initializeAppWithTimeout

    debugPrint("=== SPLASH SCREEN INITIALIZATION ===");
    debugPrint("Auth Provider Status:");
    debugPrint("  - isLoading: ${authProvider.isLoading}");
    debugPrint("  - isOfflineMode: ${authProvider.isOfflineMode}");
    debugPrint("  - user exists: ${authProvider.user != null}");
    debugPrint("  - pending invite code: $_pendingInviteCode");

    // Start notification system in BACKGROUND (non-blocking)
    unawaited(_initializeNotificationSystemInBackground());

    // Check if user can access app (online OR offline)
    if (authProvider.canAccessApp) {
      final user = authProvider.user;

      if (authProvider.isOfflineMode) {
        debugPrint("📱 OFFLINE MODE: Using cached data");
        _updateStatus('');
        await Future.delayed(const Duration(milliseconds: 300));

        // ⭐ Offline mode: Skip email verification check entirely
        await _offlineNavigationLogic(user);
        return;
      }

      // ONLINE MODE: Do quick checks
      if (user == null) {
        debugPrint("❌ User is null despite canAccessApp=true");
        _navigateToLogin();
        return;
      }

      _updateStatus('');

      // ⭐ NEW LOGIC: Only check email verification if user has no community
      if (user.communityId == null || user.communityId!.isEmpty) {
        // New user - need to check email verification
        debugPrint("👤 New user (no community) - checking email verification");
        final emailVerified = await _isUserEmailVerified();

        if (!emailVerified) {
          debugPrint("❌ Email not verified - navigate to verification screen");
          _navigateToVerificationPending(user.email);
          return;
        }
      } else {
        // User has community - assume they were verified at signup
        debugPrint("✅ User has community, skipping email verification check");
      }

      // Continue with normal flow
      await _normalNavigationLogic(user);
    } else {
      debugPrint("❌ Cannot access app - go to login");
      _navigateToLogin();
    }
  }

  Future<void> _offlineNavigationLogic(UserModel? user) async {
    if (user == null) {
      debugPrint("❌ No cached user in offline mode");
      _navigateToLogin();
      return;
    }

    // ⭐ CRITICAL: In offline mode, skip ALL verification checks
    // Just check if user has basic data

    debugPrint("📱 Offline user data:");
    debugPrint("   - Email: ${user.email}");
    debugPrint(
      "   - Has community: ${user.communityId != null && user.communityId!.isNotEmpty}",
    );
    debugPrint("   - Is approved: ${user.isApproved}");

    // Check if user has cached community data
    if (user.communityId == null || user.communityId!.isEmpty) {
      debugPrint(
        "📱 OFFLINE: No cached community - go to join community screen",
      );
      _navigateToJoinCommunity();
      return;
    }

    // Check if user is approved (from cached data)
    if (!user.isApproved) {
      debugPrint(
        "📱 OFFLINE: Cached user not approved - go to pending approval",
      );
      _navigateToPendingApproval();
      return;
    }

    // All good - go to dashboard with cached data
    debugPrint(
      "📱 OFFLINE: User has cached community and approval - go to dashboard",
    );
    if (_pendingEventId != null && _pendingEventId!.isNotEmpty) {
      _navigateToEventDetails();
    } else {
      _navigateToDashboard();
    }
  }

  // ⭐ UPDATED: Remove UserModel parnameter
  Future<bool> _isUserEmailVerified() async {
    try {
      // Reload user to get latest email verification status FROM FIREBASE AUTH
      await FirebaseAuth.instance.currentUser?.reload();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final isVerified = currentUser.emailVerified;
        debugPrint('📧 Firebase Auth email verification status: $isVerified');
        return isVerified;
      }

      debugPrint('❌ No Firebase user found');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking email verification: $e');
      return false;
    }
  }

  /// Normal navigation logic - ignore pending invites
  /// Normal navigation logic - ignore pending invites
  Future<void> _normalNavigationLogic(UserModel? user) async {
    if (user == null) {
      debugPrint("❌ User is null in normal navigation");
      _navigateToLogin();
      return;
    }

    // ⭐ NEW LOGIC: Check for missing phone number
    if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
      debugPrint("⚠️ User is missing phone number - go to set phone screen");
      _navigateToSetPhone();
      return;
    }

    // Check community (no network calls needed)
    if (user.communityId == null || user.communityId!.isEmpty) {
      debugPrint("➡️ No community - go to join");
      _navigateToJoinCommunity();
      return;
    }

    // Check approval (no network calls needed)
    if (!user.isApproved) {
      debugPrint("➡️ Not approved - go to pending");
      _navigateToPendingApproval();
      return;
    }

    // All good - go to dashboard
    debugPrint("➡️ User has community and is approved - go to dashboard");
    debugPrint("   Pending invite code saved for later: $_pendingInviteCode");
    if (_pendingEventId != null && _pendingEventId!.isNotEmpty) {
      _navigateToEventDetails();
    } else {
      _navigateToDashboard();
    }
  }

  // ⭐ NEW: Navigate to verification pending screen
  void _navigateToVerificationPending(String email) {
    if (!mounted) return;

    debugPrint('🚀 Navigating to VerificationPendingScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationPendingScreen(
          email: email,
          pendingInviteCode: _pendingInviteCode,
        ),
      ),
    );
  }

  // Navigation helpers
  void _navigateToLogin() {
    if (!mounted) {
      debugPrint('❌ Cannot navigate - widget not mounted');
      return;
    }

    debugPrint('🚀 Navigating to LoginScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(pendingInviteCode: _pendingInviteCode),
      ),
    );
  }

  void _navigateToSetPhone() {
    if (!mounted) return;

    debugPrint('🚀 Navigating to SetPhoneScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SetPhoneScreen(pendingInviteCode: _pendingInviteCode),
      ),
    );
  }

  void _navigateToJoinCommunity() {
    if (!mounted) return;

    debugPrint('🚀 Navigating to JoinCommunityScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JoinCommunityScreen(
          inviteCode: _pendingInviteCode, // Pass invite code if exists
        ),
      ),
    );
  }

  void _navigateToPendingApproval() {
    if (!mounted) return;

    debugPrint('🚀 Navigating to PendingApprovalScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
    );
  }

  void _navigateToDashboard() {
    if (!mounted) return;

    debugPrint('🚀 Navigating to CommunityDashboard');

    // Don't clear the invite code when going to dashboard
    // Keep it saved for when user manually navigates to JoinCommunityScreen
    if (_pendingInviteCode != null) {
      debugPrint('💾 Keeping invite code in storage for future use');
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CommunityDashboard()),
    );
  }

  void _navigateToEventDetails() async {
    if (!mounted || _pendingEventId == null) return;
    
    debugPrint('🚀 Navigating directly to EventDetailsScreen for: $_pendingEventId');
    
    // Clear it so it doesn't persist forever
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_event_id');
    
    // Push the dashboard as the root
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CommunityDashboard()),
    );
    
    // Then immediately push the event details on top
    // This allows the user to press the back button and go to the dashboard instead of exiting
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailsScreen(eventId: _pendingEventId!),
      ),
    );
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _status = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = AppColors.background(context);
    final primaryColor = isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Only show logo loader if NOT navigating via an event deep link
          if (widget.deepLinkEventId == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium Wave Logo Loader (XL Size - Tighter Padding)
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AnimatedLogo(
                        size: 90,
                        showBackground: true,
                        backgroundColor: primaryColor,
                        loopAnimation: true,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 100), // More breathing room without spinner
                ],
              ),
            ),

          // Status & Info (Positioned at bottom for minimalism)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isInitializing && _status.isNotEmpty && widget.deepLinkEventId == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      _status.toUpperCase(),
                      style: TextStyle(
                        color: primaryColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (_pendingInviteCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, color: primaryColor, size: 16),
                        const SizedBox(width: 10),
                        Text(
                          'INVITE ACTIVE',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}





