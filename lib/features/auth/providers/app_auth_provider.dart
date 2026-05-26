// lib/features/auth/providers/app_auth_provider.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../routing/route_names.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/services/fcm_token_service.dart';
import '../../../core/services/notification_storage_service.dart';

extension AuthNavigation on AppAuthProvider {
  /// Decide which screen to navigate after authentication
  String getInitialRoute() {
    if (!canAccessApp) return RouteNames.login;

    if (_user?.communityId == null || _user!.communityId!.isEmpty) {
      return RouteNames.joinCommunity;
    }

    if (!_user!.isApproved) return RouteNames.pendingApproval;

    return RouteNames.communityDashboard;
  }
}

class AppAuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  bool get isDeveloper {
    if (_user == null) return false;
    // Make sure isDeveloper field exists and is not null
    return _user!.isDeveloper ?? false;
  }

  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _userSubscription;
  bool _isOfflineMode = false;

  AppAuthProvider(this._authService) {
    _initializeWithOfflineSupport();
  }
  // ⭐ ADD THIS: Public method to wait for initialization
  bool get isInitialized => _user != null || _isOfflineMode;

  // ⭐ ADD THIS: Wait for initialization to complete
  Future<void> waitForInitialization() async {
    if (isInitialized) return;

    // Wait up to 3 seconds for initialization
    final startTime = DateTime.now();
    while (!isInitialized &&
        DateTime.now().difference(startTime).inSeconds < 3) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!isInitialized) {
      debugPrint("⚠️ Auth provider initialization timed out");
      // Try offline data one more time
      await _tryUseOfflineData();
    }
  }

  // ⭐ ADD THIS: Method to force check offline data
  Future<void> checkOfflineData() async {
    await _tryUseOfflineData();
  }

  // Public getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;

  String get getUserDisplayName {
    if (_user?.displayName != null && _user!.displayName!.isNotEmpty) {
      return _user!.displayName!;
    } else if (_user?.email != null) {
      return _user!.email.split('@').first;
    }
    return 'User';
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  bool get hasPasswordProvider {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    return currentUser.providerData.any(
      (userInfo) => userInfo.providerId == 'password',
    );
  }

  bool get isGoogleOnlyUser {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    final hasGoogle = currentUser.providerData.any(
      (userInfo) => userInfo.providerId == 'google.com',
    );
    return hasGoogle && !hasPasswordProvider;
  }

  // Initialize with offline support
  Future<void> _initializeWithOfflineSupport() async {
    _setLoading(true);

    try {
      // 1. Try online auth first
      final User? onlineUser = await _authService
          .getCurrentUserWithOfflineSupport();

      if (onlineUser != null) {
        debugPrint("✅ Online authentication successful");
        await _setupUserListener(onlineUser.uid);
        return;
      }

      // 2. If no online user, check offline saved data
      debugPrint("📡 No online user, checking offline saved data...");
      final offlineUserData = await _getOfflineUserData();

      if (offlineUserData != null) {
        _isOfflineMode = true;
        _user = UserModel.fromMap(offlineUserData);
        debugPrint(
          "📱 Offline mode: Using saved user data for ${_user?.displayName}",
        );
        _setLoading(false);
        notifyListeners();
        return;
      }

      // 3. No user at all (first time or signed out)
      debugPrint("📭 No saved user data found");
      _user = null;
    } catch (e) {
      debugPrint("⚠️ Auth initialization error: $e");

      // Last resort: try offline data
      try {
        final offlineUserData = await _getOfflineUserData();
        if (offlineUserData != null) {
          _isOfflineMode = true;
          _user = UserModel.fromMap(offlineUserData);
          debugPrint("📱 Offline fallback after error");
        }
      } catch (e2) {
        debugPrint("❌ Offline fallback also failed: $e2");
      }
    } finally {
      _setLoading(false);
    }

    // 4. Setup auth state listener for future changes
    _setupAuthStateListener();
  }

  // Get user data from local storage
  Future<Map<String, dynamic>?> _getOfflineUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString('kofund_user_data');

      if (userDataJson == null) {
        return null;
      }

      final userData = json.decode(userDataJson) as Map<String, dynamic>;
      final lastSaved = userData['lastSaved'] as int?;

      // Check if data is too old (more than 7 days)
      if (lastSaved != null) {
        final savedDate = DateTime.fromMillisecondsSinceEpoch(lastSaved);
        final daysSinceSaved = DateTime.now().difference(savedDate).inDays;

        if (daysSinceSaved > 7) {
          debugPrint(
            "🗑️ Offline data too old ($daysSinceSaved days), clearing",
          );
          await prefs.remove('kofund_user_data');
          return null;
        }
      }

      debugPrint("📱 Found offline user data");
      return userData;
    } catch (e) {
      debugPrint("❌ Error reading offline user data: $e");
      return null;
    }
  }

  // Save user data locally
  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataToSave = {
        ...userData,
        'lastSaved': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('kofund_user_data', json.encode(dataToSave));
      debugPrint('💾 User data saved locally');
    } catch (e) {
      debugPrint('⚠️ Error saving user data locally: $e');
    }
  }

  // Setup auth state listener
  void _setupAuthStateListener() {
    _userSubscription?.cancel();

    _userSubscription = _auth.authStateChanges().listen(
      (User? firebaseUser) async {
        if (firebaseUser != null) {
          debugPrint(
            "🔄 Auth state changed: User online - ${firebaseUser.email}",
          );
          _isOfflineMode = false; // We're online now

          await _setupUserListener(firebaseUser.uid);

          // Save user data locally when we get it
          final userData = await _authService.getUserData(firebaseUser.uid);
          if (userData != null) {
            _user = UserModel.fromMap(userData);
            await _saveUserDataLocally(_user!.toMap());
          }
        } else {
          debugPrint("🔄 Auth state changed: User signed out online");
          // Don't clear local data immediately - keep for offline
          _isOfflineMode = true; // Switch to offline mode
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("⚠️ Auth state listener error: $error");
        // On error, try to use offline data
        if (_user == null) {
          _tryUseOfflineData();
        }
      },
    );
  }

  // Try to use offline data
  Future<void> _tryUseOfflineData() async {
    try {
      final offlineUserData = await _getOfflineUserData();
      if (offlineUserData != null) {
        _isOfflineMode = true;
        _user = UserModel.fromMap(offlineUserData);
        debugPrint("📱 Switching to offline mode with saved data");
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Failed to use offline data: $e");
    }
  }

  // Setup user listener
  Future<void> _setupUserListener(String uid) async {
    try {
      _firestore
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen(
            (doc) async {
              if (doc.exists) {
                final userData = doc.data()!;
                _user = UserModel.fromMap(userData);
                _isOfflineMode = false; // We have freshhh data

                // Save locally for offline use
                await _saveUserDataLocally(_user!.toMap());

                notifyListeners();
              }
            },
            onError: (error) {
              debugPrint("⚠️ User listener error: $error");
              // On error, check if we have offline data
              if (_user == null) {
                _tryUseOfflineData();
              }
            },
          );
    } catch (e) {
      debugPrint('❌ Error setting up user listener: $e');
      _tryUseOfflineData();
    }
  }

  // Check if user can access app (online OR offline)
  bool get canAccessApp {
    return _user != null || _isOfflineMode;
  }

  // ⭐ ADD THIS: Update user's phone number
  Future<bool> updateUserPhoneNumber(String phoneNumber) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      _setLoading(true);
      await _firestore.collection('users').doc(currentUser.uid).update({
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local user object
      if (_user != null) {
        _user = _user!.copyWith(phoneNumber: phoneNumber);
        await _saveUserDataLocally(_user!.toMap());
        notifyListeners();
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update phone number: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Synchronize community name with user profile for better caching
  Future<void> syncCommunityName(String communityName) async {
    if (_user == null || _user!.communityName == communityName) return;

    try {
      debugPrint('🔄 Synchronizing community name for user: $communityName');
      await _firestore.collection('users').doc(_user!.uid).update({
        'communityName': communityName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Local update is handled by the snapshot listener
      _user = _user!.copyWith(communityName: communityName);
      await _saveUserDataLocally(_user!.toMap());
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Failed to sync community name: $e');
    }
  }


  Future<void> saveFcmTokenForCurrentUser() async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) return;
      
      // ✅ Use FCMTokenService for consistency (passing current communityId if available)
      final fcmTokenService = FCMTokenService();
      final communityIds = _user?.communityId != null ? [_user!.communityId!] : <String>[];
      await fcmTokenService.storeCurrentUserToken(communityIds: communityIds);
      
      debugPrint('✅ FCM token saved via service for ${current.uid}');
    } catch (e) {
      debugPrint('⚠️ Failed saving FCM token via service: $e');
    }
  }

  Future<void> refreshUserData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final userData = await _authService.getUserData(firebaseUser.uid);
      if (userData != null) {
        _user = UserModel.fromMap(userData);
        notifyListeners();
      }
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      // Create user with email and password using auth service
      final user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      if (user != null) {
        // Save user data to Firestore
        await _saveUserToFirestore(
          userId: user.uid,
          email: email,
          name: name,
          phoneNumber: phone,
        );

        // Send email verification
        await user.sendEmailVerification();

        debugPrint('✅ Verification email sent to: $email');

        // ✅ REGISTER FCM TOKEN AFTER SIGNUP
        await saveFcmTokenForCurrentUser();

        // Keep user signed in so they can access verification screen
        // The user will remain signed in but won't be able to access main app until verified

        // Get the updated user data
        final userData = await _authService.getUserData(user.uid);
        if (userData != null) {
          _user = UserModel.fromMap(userData);
        }

        _setLoading(false);
        notifyListeners();
        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // Handle unverified users
  void handleUnverifiedUser() {
    // This will be called when an unverified user tries to login
    // Keep them signed in but show verification screen
    _error =
        'Please verify your email before logging in. Check your inbox for the verification link.';
    notifyListeners();
  }

  // Save user data with verification status
  Future<void> _saveUserToFirestore({
    required String userId,
    required String email,
    required String name,
    required String phoneNumber,
  }) async {
    try {
      final userData = {
        'uid': userId,
        'email': email,
        'displayName': name,
        'phoneNumber': phoneNumber,
        'isApproved': false,
        'isAdmin': false,
        'role': 'member',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // ✅ ADD THESE FOR NOTIFICATIONS:
        'fcmTokens': [], // Will be populated when token is registered
        'notificationCommunities':
            [], // Will be updated when user joins a community
        'notificationSettings': {
          'enabled': true,
          'announcements': true,
          'events': true,
          'reminders': true,
          'contributions': true,
        },
      };

      await _firestore.collection('users').doc(userId).set(userData);
      debugPrint('✅ User data saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving user to Firestore: $e');
      rethrow;
    }
  }

  // ✅ UPDATED: Improved login method with FCM token registration
  Future<bool> signIn({required String email, required String password}) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.signIn(email: email, password: password);

      if (user != null) {
        // Check verification
        await user.reload();
        final currentUser = _auth.currentUser;

        if (currentUser != null && !currentUser.emailVerified) {
          _setError('Please verify your email before accessing the app.');

          // Still save user data for verification screen
          final userData = await _authService.getUserData(user.uid);
          if (userData != null) {
            _user = UserModel.fromMap(userData);
            await _saveUserDataLocally(_user!.toMap());
          }

          _setLoading(false);
          notifyListeners();
          return false;
        }

        // Get and save user data
        final userData = await _authService.getUserData(user.uid);
        if (userData != null) {
          _user = UserModel.fromMap(userData);
          await _saveUserDataLocally(_user!.toMap());
        }

        // ✅ REGISTER FCM TOKEN FOR NOTIFICATIONS
        await saveFcmTokenForCurrentUser();

        _isOfflineMode = false; // We're online now
        _setLoading(false);
        notifyListeners();
        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // REMOVED manual FCM registration methods as they are now handled by FCMTokenService

  // ✅ Check if current user needs verification
  bool get needsEmailVerification {
    return _user != null &&
        _auth.currentUser != null &&
        !_auth.currentUser!.emailVerified;
  }

  bool get shouldNavigateToVerification {
    return _auth.currentUser != null &&
        !_auth.currentUser!.emailVerified &&
        _user != null;
  }

  // ✅ Get current user email for verification screen
  String? get currentUserEmail {
    return _auth.currentUser?.email ?? _user?.email;
  }

  // Resend verification email
  Future<bool> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e));
      return false;
    }
  }

  // Check if current user is verified
  bool isCurrentUserVerified() {
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Reload user to get latest verification status
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _error = null;

    try {
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // For Google accounts, they are typically verified, but let's check if user exists in Firestore
        final userData = await _authService.getUserData(user.uid);

        if (userData != null) {
          _user = UserModel.fromMap(userData);
        } else {
          // Create user profile for Google sign-in user
          debugPrint('Creating user profile for Google sign-in user...');
          final userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? 'Google User',
            phoneNumber: user.phoneNumber ?? '',
            role: 'member',
            isApproved: false,
            createdAt: Timestamp.now(),
          );

          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(userModel.toMap());

          _user = userModel;
        }

        // ✅ CRITICAL: Save user data locally for offline support
        final updatedUserData = await _authService.getUserData(user.uid);
        if (updatedUserData != null) {
          _user = UserModel.fromMap(updatedUserData);
          await _saveUserDataLocally(_user!.toMap());
        }

        // ✅ REGISTER FCM TOKEN FOR GOOGLE SIGN-IN USERS
        await saveFcmTokenForCurrentUser();

        _isOfflineMode = false; // We're online now
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        // ⭐ CHANGED: Don't set error for cancellation - just return false
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ GOOGLE SIGN-IN ERROR: $e');

      // ⭐ CHANGED: Only set error if it's NOT a cancellation
      if (!_isGoogleCancellationError(e)) {
        _setError(_getAuthErrorMessage(e));
      } else {
        debugPrint('🔄 Google sign-in was cancelled by user');
      }

      _setLoading(false);
      return false;
    }
  }

  // ⭐ ADD THIS HELPER METHOD to detect Google cancellation errors
  bool _isGoogleCancellationError(dynamic error) {
    if (error is FirebaseAuthException) {
      return error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'access_denied' ||
          (error.message?.toLowerCase().contains('cancelled') == true) ||
          (error.message?.toLowerCase().contains('canceled') == true);
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('cancelled') ||
        errorString.contains('canceled') ||
        errorString.contains('popup closed') ||
        errorString.contains('popup-closed') ||
        errorString.contains('signin was cancelled') ||
        errorString.contains('sign-in was cancelled');
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _error = null;

      await _authService.sendPasswordResetEmail(email);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // Change password with current password verification
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final success = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      _setLoading(false);
      return success;
    } catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // Re-authenticate user (required for sensitive operations)
  Future<bool> reauthenticateUser(String password) async {
    try {
      final success = await _authService.reauthenticateUser(password);
      return success;
    } catch (e) {
      _setError(_getAuthErrorMessage(e));
      return false;
    }
  }

  // Update password directly (without current password - for admin scenarios)
  Future<bool> updatePassword(String newPassword) async {
    try {
      _setLoading(true);
      _error = null;

      final success = await _authService.updatePassword(newPassword);

      _setLoading(false);
      return success;
    } catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  String _getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      // ⭐ CHECK FOR CANCELLATION FIRST
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.message?.toLowerCase().contains('cancelled') == true ||
          error.message?.toLowerCase().contains('canceled') == true) {
        return ''; // Return empty string for cancellation
      }

      switch (error.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Please sign in instead.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email but different sign-in method.';
        case 'invalid-credential':
          return 'The authentication credential is invalid.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled. Please contact support.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'popup-closed-by-user':
          return ''; // Empty for cancellation
        case 'popup-blocked':
          return 'Popup was blocked. Please allow popups for this site.';
        default:
          return 'Authentication failed: ${error.message}';
      }
    }

    if (error.toString().contains('signInWithPopup') ||
        error.toString().contains('signInWithRedirect')) {
      if (kIsWeb) {
        return 'Google sign-in popup was blocked. Please allow popups for this site.';
      } else {
        return 'Google sign-in is not available on this platform.';
      }
    }

    if (error.toString().contains('platform')) {
      return 'This feature is not supported on your device.';
    }

    return 'An error occurred: $error';
  }

  Future<void> signOut(BuildContext context) async {
    try {
      debugPrint('🔄 AppAuthProvider: Starting sign-out process...');

      // ------------------------------------------------------------------
      // 1. Clear local subscription (only our own)
      // ------------------------------------------------------------------
      try {
        _userSubscription?.cancel();
        _userSubscription = null;
        debugPrint('✅ Local subscriptions cleared');
      } catch (e) {
        debugPrint('⚠️ Error clearing local subscriptions: $e');
      }

      // ------------------------------------------------------------------
      // 2. Clear Notification & Token Services (MOST IMPORTANT)
      // ------------------------------------------------------------------
      try {
        final tokenService = Provider.of<FCMTokenService>(
          context,
          listen: false,
        );
        final storageService = Provider.of<NotificationStorageService>(
          context,
          listen: false,
        );

        // ⭐ CRITICAL: Clean up FCM token for current user
        await tokenService.handleUserLogout();
        debugPrint("🔕 FCM token detached from user");

        // Cleanup notification storage
        await storageService.cleanupForUserLogout();
        debugPrint("🗑️ Notification storage cleaned up");
      } catch (e) {
        debugPrint("⚠️ Notification service cleanup error: $e");
      }

      // ------------------------------------------------------------------
      // 3. Clear Provider state (optional - they will reset on next login)
      // ------------------------------------------------------------------
      try {
        // These providers will automatically reset when user logs in again
        debugPrint('🔄 Provider states will reset on next login');
      } catch (e) {
        debugPrint('⚠️ Provider clear error: $e');
      }

      // ------------------------------------------------------------------
      // 4. Firebase Auth Sign Out
      // ------------------------------------------------------------------
      await _authService.signOut();
      debugPrint("🟦 FirebaseAuth: Signed out");

      // ------------------------------------------------------------------
      // 5. Clear Local State
      // ------------------------------------------------------------------
      _user = null;
      _isOfflineMode = false;
      _isLoading = false;
      _error = null;

      // ------------------------------------------------------------------
      // 6. Clear SharedPreferences (CRITICAL for notification cleanup)
      // ------------------------------------------------------------------
      try {
        final prefs = await SharedPreferences.getInstance();

        // Clear auth data
        await prefs.remove('kofund_user_data');
        await prefs.remove('cached_community');
        await prefs.remove('last_profile_sync');

        // ⭐ CRITICAL: Clear notification user ID to p cross-user notifications
        await prefs.remove('current_notification_user_id');

        // Clear notification settings
        await prefs.remove('notification_muted_communities');
        await prefs.remove('user_communities');
        await prefs.remove('notification_announcement');
        await prefs.remove('notification_event');
        await prefs.remove('notification_reminder');
        await prefs.remove('notification_contribution');
        await prefs.remove('notification_expense');
        await prefs.remove('notifications_enabled');

        debugPrint("🗑 SharedPreferences cleared");
      } catch (e) {
        debugPrint("⚠️ Error clearing SharedPreferences: $e");
      }

      // ------------------------------------------------------------------
      // DONE
      // ------------------------------------------------------------------
      debugPrint('✅ AppAuthProvider: Sign-out completed successfully');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('❌ Sign-out error: $e');
      debugPrint(stack.toString());

      // Fail-safe cleanup
      _user = null;
      _isOfflineMode = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateUserCommunity({
    required String communityId,
    required String communityName,
    required String role,
    bool isApproved = false,
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    _error = null;

    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'communityId': communityId,
        'communityName': communityName,
        'role': role,
        'isApproved': isApproved,
        if (isApproved) 'approvedAt': FieldValue.serverTimestamp(),
      });

      _user = _user!.copyWith(
        communityId: communityId,
        communityName: communityName,
        role: role,
        isApproved: isApproved,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update user community: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> setUserAsCommunityAdmin({
    required String communityId,
    required String communityName,
  }) async {
    return await updateUserCommunity(
      communityId: communityId,
      communityName: communityName,
      role: 'admin',
      isApproved: true,
    );
  }

  Future<bool> removeUserFromCommunity() async {
    if (_user == null || _user!.communityId == null) return false;

    _setLoading(true);
    _error = null;

    try {
      await _firestore
          .collection('communities')
          .doc(_user!.communityId!)
          .collection('members')
          .doc(_user!.uid)
          .delete();

      await _firestore.collection('users').doc(_user!.uid).update({
        'communityId': FieldValue.delete(),
        'communityName': FieldValue.delete(),
        'role': FieldValue.delete(),
        'isApproved': false,
      });

      _user = _user!.copyWith(
        communityId: null,
        communityName: null,
        role: 'member',
        isApproved: false,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to leave community: $e');
      _setLoading(false);
      return false;
    }
  }

  bool get canAccessCommunityDashboard {
    return _user != null &&
        _user!.communityId != null &&
        _user!.communityId!.isNotEmpty &&
        _user!.isApproved;
  }

  bool get isWaitingForApproval {
    return _user != null &&
        _user!.communityId != null &&
        _user!.communityId!.isNotEmpty &&
        !_user!.isApproved;
  }

  bool get needsToJoinCommunity {
    return _user != null &&
        (_user!.communityId == null || _user!.communityId!.isEmpty);
  }

  Future<void> refreshUserDataWithOfflineSupport() async {
    if (_isOfflineMode) {
      // In offline mode, just use local data
      final offlineData = await _getOfflineUserData();
      if (offlineData != null) {
        _user = UserModel.fromMap(offlineData);
        notifyListeners();
      }
    } else {
      // Online mode - refresh from server
      await refreshUserData();
    }
  }

  Future<void> makeDeveloper(String userId, bool isDeveloper) async {
    if (!this.isDeveloper) {
      throw Exception('Only developers can modify developer status');
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isDeveloper': isDeveloper,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Refresh current user if modifying self
    if (userId == _user?.uid) {
      await refreshUserData();
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}





