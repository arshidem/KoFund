// lib/features/auth/screens/splash_screen.dart 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/providers/app_auth_provider.dart' as app_auth;
import '../../../features/auth/screens/login_screen.dart';
import '../../../features/auth/screens/verification_pending_screen.dart';
import '../../../features/community/screens/join_community_screen.dart';
import '../../../features/community/screens/community_dashboard.dart';
import '../../../features/community/screens/pending_approval_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';

import '../../../core/services/fcm_token_service.dart';
import '../../../features/notifications/providers/notification_provider.dart';
// Import your animated logo
import '../../../core/widgets/animated_logo.dart';

void unawaited(Future<void> future) {}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitializing = true;
  String _status = 'Starting app...';

  @override
  void initState() {
    super.initState();
    _startSplashTimer();
  }
  /// ⭐ NEW: Ensure splash shows for at least 2 seconds
void _startSplashTimer() {
  Future.delayed(const Duration(seconds: 3), () {
    if (!mounted) return;
    _initializeAppWithTimeout(); // your existing logic
  });
}

  /// ⭐ NEW: Initialize notification system ASYNCHRONOUSLY
  Future<void> _initializeNotificationSystemInBackground() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      debugPrint("🔄 Background: Initializing notification system...");
      
      // Get services from context
      final tokenService = Provider.of<FCMTokenService>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      
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
          debugPrint("🏘️ Using cached communities: ${cachedCommunities.join(', ')}");
          await tokenService.storeCurrentUserToken(communityIds: cachedCommunities);
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
        final communities = (userData?['notificationCommunities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        
        // Cache for next time
        if (communities.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('user_communities', communities);
        }
        
        if (communities.isEmpty) {
          debugPrint("🏘️ User has no communities for notifications");
          await tokenService.storeCurrentUserToken(communityIds: []);
        } else {
          debugPrint("🏘️ Initializing with communities: ${communities.join(', ')}");
          await tokenService.storeCurrentUserToken(communityIds: communities);
        }
        
        notificationProvider.updateUserCommunities(communities);
        
      } on TimeoutException {
        debugPrint("⏱️ Notification initialization timed out (continuing)");
      } catch (e) {
        debugPrint("❌ Notification initialization failed: $e");
      }
      
    } catch (e, stackTrace) {
      debugPrint("❌ Background notification init error: $e");
      // Don't throw - notification system should not block app
    }
  }

  /// ⭐ NEW: Main initialization with timeout
  Future<void> _initializeAppWithTimeout() async {
    try {
      _updateStatus('Starting app...');
      
      // Get auth provider
      final authProvider = Provider.of<app_auth.AppAuthProvider>(context, listen: false);
      
      // Wait MAX 3 seconds total
      await Future.any([
        _performInitialization(authProvider),
        Future.delayed(const Duration(seconds: 3)),
      ]);
      
    } catch (e) {
      debugPrint("❌ Splash initialization error: $e");
      // Still navigate even on error
      _navigateToLogin();
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _performInitialization(app_auth.AppAuthProvider authProvider) async {
    // Short delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 800));
    
    debugPrint("=== SPLASH SCREEN ===");
    debugPrint("Auth Provider Status:");
    debugPrint("  - isLoading: ${authProvider.isLoading}");
    debugPrint("  - isOfflineMode: ${authProvider.isOfflineMode}");
    debugPrint("  - user exists: ${authProvider.user != null}");
    
    // ⭐ NEW: Start notification system in BACKGROUND (non-blocking)
    unawaited(_initializeNotificationSystemInBackground());
    
    // Check if user can access app (online OR offline)
    if (authProvider.canAccessApp) {
      final user = authProvider.user;
      
      if (authProvider.isOfflineMode) {
        debugPrint("📱 OFFLINE MODE: Using cached data");
        _updateStatus('Loading offline data...');
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToDashboard();
        return;
      }
      
      // ONLINE MODE: Do quick checks
      if (user == null) {
        debugPrint("❌ User is null despite canAccessApp=true");
        _navigateToLogin();
        return;
      }
      
      _updateStatus('Checking account...');
      
      // Quick navigation logic (non-blocking)
      await _quickNavigationLogic(user);
      
    } else {
      debugPrint("❌ Cannot access app - go to login");
      _navigateToLogin();
    }
  }

  Future<void> _quickNavigationLogic(UserModel? user) async {
    if (user == null) {
      _navigateToLogin();
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
    debugPrint("➡️ All good - go to dashboard");
    _navigateToDashboard();
  }

  // Navigation helpers
  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigateToJoinCommunity() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const JoinCommunityScreen()),
    );
  }

  void _navigateToPendingApproval() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
    );
  }

  void _navigateToDashboard() {
    if (!mounted) return;
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
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Logo only (transparent background)
          const AnimatedLogo(
            size: 200,
            showBackground: false,
            loopAnimation: true,
          ),
          
          const SizedBox(height: 20),
          
          // Status text only when loading
      
        ],
      ),
    ),
  ),
);
  }
}