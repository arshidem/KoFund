// lib/features/auth/screens/splash_screen.dart
import 'package:flutter/material.dart';
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
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/fcm_token_service.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../core/widgets/animated_logo.dart';

void unawaited(Future<void> future) {}

class SplashScreen extends StatefulWidget {
  final String? deepLinkInviteCode;
  const SplashScreen({super.key, this.deepLinkInviteCode});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitializing = true;
  String _status = '';
  String? _pendingInviteCode;

  @override
  void initState() {
    super.initState();
    _handleInviteCode();
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

      // ⭐ Start the 1.0-second animation timer
      final splashTimer = Future.delayed(const Duration(milliseconds: 1000));

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
    _navigateToDashboard();
  }

  // ⭐ UPDATED: Remove UserModel parameter
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
    _navigateToDashboard();
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

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _status = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AppAuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient(context)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo only (transparent background)
              const AnimatedLogo(
                size: 140, // Reduced from 200
                showBackground: false,
                loopAnimation: true,
              ),

              const SizedBox(height: 20),

              // Status text only when loading
              if (_isInitializing && _status.isNotEmpty)
                Column(
                  children: [
                    Text(
                      _status,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),

              // Show invite code indicator if exists
              if (_pendingInviteCode != null)
                Container(
                  margin: const EdgeInsets.only(top: 30),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Invite code saved',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
