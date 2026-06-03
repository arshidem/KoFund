import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SecureStorageService _secureStorage = SecureStorageService();

  static const String _authStateKey = 'kofund_auth_state';
  static const String _userDataKey = 'kofund_user_data';
  static const String _lastLoginKey = 'kofund_last_login';

  // Get current user
  // Get current user with offline fallback
  Future<User?> getCurrentUserWithOfflineSupport() async {
    try {
      // First try to get from Firebase (works online)
      final User? firebaseUser = _auth.currentUser;
      
      if (firebaseUser != null) {
        if (kDebugMode) debugPrint('✅ Auth: Online session active');
        await _saveAuthStateLocally(firebaseUser);
        return firebaseUser;
      }
      
      // If Firebase returns null, try local storage (offline mode)
      if (kDebugMode) debugPrint('⚠️ Auth: No online user, checking secure storage');
      return await _getUserFromLocalStorage();
      
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      // Fallback to local storage
      return await _getUserFromLocalStorage();
    }
  }

  // Save auth state locally for offline use
  Future<void> _saveAuthStateLocally(User user) async {
    try {
      
      // Save basic auth info
      final authState = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'phoneNumber': user.phoneNumber,
        'photoURL': user.photoURL,
        'isAnonymous': user.isAnonymous,
        'metadata': {
          'creationTime': user.metadata.creationTime?.millisecondsSinceEpoch,
          'lastSignInTime': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
        },
        'lastSaved': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _secureStorage.write(_authStateKey, json.encode(authState));
      if (kDebugMode) debugPrint('💾 Auth state encrypted and saved');
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error saving auth state: $e');
    }
  }

  // Get user from local storage (offline mode)
  Future<User?> _getUserFromLocalStorage() async {
    try {
      final authStateJson = await _secureStorage.read(_authStateKey);
      
      if (authStateJson == null) {
        if (kDebugMode) debugPrint('📭 No secured auth state found');
        return null;
      }
      
      final authState = json.decode(authStateJson) as Map<String, dynamic>;
      final lastSaved = authState['lastSaved'] as int?;
      
      if (lastSaved == null) {
        return null;
      }
      
      // Check if saved state is too old (more than 30 days)
      final savedDate = DateTime.fromMillisecondsSinceEpoch(lastSaved);
      final daysSinceSaved = DateTime.now().difference(savedDate).inDays;
      
      if (daysSinceSaved > 30) {
        if (kDebugMode) debugPrint('🗑️ Secured auth state expired ($daysSinceSaved days)');
        await _secureStorage.delete(_authStateKey);
        return null;
      }
      
      if (kDebugMode) debugPrint('📱 Using secured auth from $daysSinceSaved days ago');
      
      // Create a mock user or just return null
      // For offline mode, we'll rely on the saved UID in providers
      return null; // Return null but we'll handle offline mode elsewhere
      
    } catch (e) {
      debugPrint('❌ Error reading auth state from local storage: $e');
      return null;
    }
  }

  // Clear local auth state
  Future<void> clearLocalAuthState() async {
    try {
      await _secureStorage.delete(_authStateKey);
      await _secureStorage.delete(_userDataKey);
      await _secureStorage.delete(_lastLoginKey);
      if (kDebugMode) debugPrint('🗑️ Secure auth state cleared');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error clearing secure state: $e');
    }
  }

  // Save user data locally
  Future<void> saveUserDataLocally(Map<String, dynamic> userData) async {
    try {
      await _secureStorage.write(_userDataKey, json.encode(userData));
      if (kDebugMode) debugPrint('💾 User data encrypted and saved');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error saving user data: $e');
    }
  }

  // Get user data from local storage
  Future<Map<String, dynamic>?> getUserDataFromLocalStorage() async {
    try {
      final userDataJson = await _secureStorage.read(_userDataKey);
      
      if (userDataJson == null) {
        return null;
      }
      
      return json.decode(userDataJson) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error reading secured user data: $e');
      return null;
    }
  }



  // ✅ FIXED: Added name and phone parameters
  Future<User?> signUp({
    required String email,
    required String password,
    required String name, // ✅ ADDED
    required String phone, // ✅ ADDED
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name in Firebase Auth
      await userCredential.user!.updateDisplayName(name);
      
      // Create user in Firestore
      final userModel = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        displayName: name,
        phoneNumber: phone,
        role: 'member',
        isApproved: false,
        createdAt: Timestamp.now(),
      );
      
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap(), SetOptions(merge: true));
      
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

// GOOGLE SIGN IN - PROPER PLATFORM DETECTION WITH CANCELLATION HANDLING
Future<User?> signInWithGoogle() async {
  try {
    if (kIsWeb) {
      // WEB IMPLEMENTATION
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
      final User? user = userCredential.user;
      
      if (user != null) {
        await _createOrUpdateUserInFirestore(user);
      }
      
      return user;
    } else {
      // MOBILE IMPLEMENTATION (Android & iOS)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // ⭐ FIX: Handle cancellation gracefully
      if (googleUser == null) {
        debugPrint('🔄 Google sign-in was cancelled by user');
        return null; // ⭐ Return null instead of throwing
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        await _createOrUpdateUserInFirestore(user);
      }
      
      return user;
    }
  } catch (e) {
    // ⭐ FIX: Check for cancellation errors in exception
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('cancelled') ||
        errorString.contains('canceled') ||
        errorString.contains('popup closed') ||
        errorString.contains('popup-closed') ||
        errorString.contains('signin was cancelled') ||
        errorString.contains('sign-in was cancelled') ||
        (e is FirebaseAuthException && 
         (e.code == 'popup-closed-by-user' || 
          e.code == 'cancelled-popup-request'))) {
      debugPrint('🔄 Google sign-in was cancelled: $e');
      return null; // ⭐ Return null for cancellation
    }
    
    debugPrint('❌ Google Sign-In Error: $e');
    rethrow; // Re-throw actual errors
  }
}

  Future<void> _createOrUpdateUserInFirestore(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Google User',
        phoneNumber: user.phoneNumber ?? '',
        role: 'member',
        isApproved: false,
        createdAt: Timestamp.now(),
      );
      
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      debugPrint('✅ New Google user created in Firestore: ${user.uid}');
    } else {
      // Update last login for existing user
      await _firestore.collection('users').doc(user.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Existing Google user updated: ${user.uid}');
    }
  }

  // Add this to your existing signIn method
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔄 Starting REAL login for: $email');
      
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // ✅ NEW: Save auth state locally
      await _saveAuthStateLocally(credential.user!);
      
      // ✅ NEW: Get and save user data locally
      final userData = await getUserData(credential.user!.uid);
      if (userData != null) {
        await saveUserDataLocally(userData);
      }

      debugPrint('✅ Login successful for: ${credential.user!.uid}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      throw 'Login failed. Please try again.';
    }
  }

  // Add this to your existing signOut method
// In FirebaseAuthService
Future<void> signOut() async {
  try {
    debugPrint('🔄 FirebaseAuthService: Starting sign-out');

    // 1. Cache user ID BEFORE sign out
    final user = _auth.currentUser;

    // 2. Sign out from Google (only if user used Google)
    try {
      if (!kIsWeb && await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        debugPrint('🔵 Google sign-out complete');
      }
    } catch (e) {
      debugPrint('⚠️ Google sign-out error: $e');
    }

    // 3. Clean FCM token ONCE (AppAuthProvider will NOT duplicate)
 

    // 4. Sign out Firebase Auth
    await _auth.signOut();
    debugPrint('🟦 FirebaseAuth: Signed out');

    // 5. DO NOT WIPE SharedPreferences HERE
    // AppAuthProvider already removes user-only data
    // Clearing everything breaks app settings
    // So we remove only auth-related items
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kofund_user_data');
    await prefs.remove('cached_community');

    // 6. Verify user
    await Future.delayed(Duration(milliseconds: 150));
    if (_auth.currentUser == null) {
      debugPrint('✅ FirebaseAuthService: Sign-out confirmed');
    }

  } catch (e) {
    debugPrint('❌ FirebaseAuthService sign-out error: $e');
    rethrow;
  }
}

// ===== NEW METHOD: Clean FCM tokens on logout =====
Future<void> _cleanFCMTokensOnLogout(String userId) async {
  try {
    debugPrint('🧹 Cleaning FCM tokens for user: $userId');
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!userDoc.exists) {
      debugPrint('⚠️ User document not found for token cleanup');
      return;
    }
    
    final userData = userDoc.data();
    final tokens = List<String>.from(userData?['fcmTokens'] ?? []);
    
    if (tokens.isEmpty) {
      debugPrint('✅ No FCM tokens to clean');
      return;
    }
    
    debugPrint('📱 Removing ${tokens.length} FCM tokens...');
    
    // Remove all tokens from Firestore
    await userDoc.reference.update({
      'fcmTokens': FieldValue.arrayRemove(tokens)
    });
    
    // Also clean from fcm_tokens subcollection
    try {
      final tokensCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fcm_tokens');
      
      final tokensSnapshot = await tokensCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      if (tokensSnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        
        for (var doc in tokensSnapshot.docs) {
          batch.update(doc.reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'deactivatedReason': 'user_logged_out',
          });
        }
        
        await batch.commit();
        debugPrint('✅ Deactivated ${tokensSnapshot.docs.length} tokens in subcollection');
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning subcollection: $e');
    }
    
    debugPrint('✅ FCM tokens cleaned successfully');
    
  } catch (e) {
    debugPrint('❌ Error in _cleanFCMTokensOnLogout: $e');
    rethrow;
  }
}
 Future<void> initializeAuthService() async {
    try {
      // Set persistence to LOCAL (already done in main.dart, but do it here too)
      await _auth.setPersistence(Persistence.LOCAL);
      debugPrint('✅ Auth persistence set to LOCAL');
      
      // Listen for auth state changes
      _auth.authStateChanges().listen((User? user) {
        if (user != null) {
          debugPrint('👤 Auth state changed: User authenticated - ${user.email}');
          _saveAuthStateLocally(user);
          
          // Fetch and save user data
          getUserData(user.uid).then((userData) {
            if (userData != null) {
              saveUserDataLocally(userData);
            }
          });
        } else {
          debugPrint('👤 Auth state changed: User signed out');
          // Don't clear local state immediately - keep for offline
        }
      });
      
    } catch (e) {
      debugPrint('⚠️ Error initializing auth service: $e');
    }
  }
  // Get user data from Firestore (force server read to avoid stale cache)
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      // ⭐ CRITICAL: Force server read to avoid stale cached data
      // (e.g. after leaving a community, the cached doc still has the old communityId)
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (userDoc.exists) {
        debugPrint('✅ User data retrieved from Firestore (server)');
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Server read failed, falling back to cache: $e');
      // Fallback to default (cache + server) if server-only read fails
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          debugPrint('✅ User data retrieved from Firestore (cache fallback)');
          return userDoc.data() as Map<String, dynamic>;
        }
      } catch (e2) {
        debugPrint('❌ Error getting user data (fallback): $e2');
      }
      return null;
    }
  }
// Add this method to your FirebaseAuthService class
Future<void> sendPasswordResetEmail(String email) async {
  try {
    debugPrint('🔄 Sending password reset email to: $email');
    await _auth.sendPasswordResetEmail(email: email);
    debugPrint('✅ Password reset email sent successfully');
  } on FirebaseAuthException catch (e) {
    debugPrint('❌ Password reset error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    debugPrint('❌ Unexpected error in password reset: $e');
    throw 'Failed to send password reset email. Please try again.';
  }
}
// Add these methods to your FirebaseAuthService class

// Change password with current password verification
Future<bool> changePassword({
  required String currentPassword,
  required String newPassword,
}) async {
  try {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'No user is currently signed in.';
    }

    // Re-authenticate user first
    await _reauthenticateUser(user, currentPassword);

    // Update to new password
    await user.updatePassword(newPassword);
    
    debugPrint('✅ Password changed successfully');
    return true;
  } on FirebaseAuthException catch (e) {
    debugPrint('❌ Password change error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    debugPrint('❌ Unexpected error in password change: $e');
    throw 'Failed to change password. Please try again.';
  }
}

// Re-authenticate user with current password
Future<bool> reauthenticateUser(String password) async {
  try {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'No user is currently signed in.';
    }

    await _reauthenticateUser(user, password);
    return true;
  } on FirebaseAuthException catch (e) {
    debugPrint('❌ Reauthentication error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    debugPrint('❌ Unexpected error in reauthentication: $e');
    throw 'Authentication failed. Please check your password.';
  }
}

// Helper method for reauthentication
Future<void> _reauthenticateUser(User user, String password) async {
  try {
    // For email/password users
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'wrong-password') {
      throw 'Current password is incorrect.';
    }
    rethrow;
  }
}

// Update password directly (use with caution)
Future<bool> updatePassword(String newPassword) async {
  try {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'No user is currently signed in.';
    }

    await user.updatePassword(newPassword);
    debugPrint('✅ Password updated successfully');
    return true;
  } on FirebaseAuthException catch (e) {
    debugPrint('❌ Password update error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    debugPrint('❌ Unexpected error in password update: $e');
    throw 'Failed to update password. Please try again.';
  }
}
  // Error handling
// Error handling
String _handleAuthError(FirebaseAuthException e) {
  // ⭐ FIX: Check for cancellation first
  if (e.code == 'popup-closed-by-user' ||
      e.code == 'cancelled-popup-request' ||
      e.message?.toLowerCase().contains('cancelled') == true ||
      e.message?.toLowerCase().contains('canceled') == true) {
    return ''; // ⭐ Return empty string for cancellation
  }
  
  switch (e.code) {
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
    case 'popup-closed-by-user':
      return ''; // Already handled above
    case 'user-disabled':
      return 'This account has been disabled. Please contact support.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Please check your internet connection.';
    default:
      return 'An error occurred: ${e.message}';
  }
}
}






