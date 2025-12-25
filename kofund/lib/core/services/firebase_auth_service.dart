import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer; // ADD THIS for debugPrint

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
        debugPrint('✅ Firebase Auth: User authenticated online');
        await _saveAuthStateLocally(firebaseUser);
        return firebaseUser;
      }
      
      // If Firebase returns null, try local storage (offline mode)
      debugPrint('⚠️ Firebase Auth: No user found, checking local storage');
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
      final prefs = await SharedPreferences.getInstance();
      
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
      
      await prefs.setString(_authStateKey, json.encode(authState));
      debugPrint('💾 Auth state saved locally for offline');
      
    } catch (e) {
      debugPrint('⚠️ Error saving auth state locally: $e');
    }
  }

  // Get user from local storage (offline mode)
  Future<User?> _getUserFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authStateJson = prefs.getString(_authStateKey);
      
      if (authStateJson == null) {
        debugPrint('📭 No saved auth state found locally');
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
        debugPrint('🗑️ Saved auth state is too old ($daysSinceSaved days), clearing');
        await prefs.remove(_authStateKey);
        return null;
      }
      
      debugPrint('📱 Using saved auth state from ${daysSinceSaved} days ago');
      
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authStateKey);
      await prefs.remove(_userDataKey);
      await prefs.remove(_lastLoginKey);
      debugPrint('🗑️ Local auth state cleared');
    } catch (e) {
      debugPrint('⚠️ Error clearing local auth state: $e');
    }
  }

  // Save user data locally
  Future<void> saveUserDataLocally(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataKey, json.encode(userData));
      debugPrint('💾 User data saved locally for offline');
    } catch (e) {
      debugPrint('⚠️ Error saving user data locally: $e');
    }
  }

  // Get user data from local storage
  Future<Map<String, dynamic>?> getUserDataFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString(_userDataKey);
      
      if (userDataJson == null) {
        return null;
      }
      
      return json.decode(userDataJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ Error reading user data from local storage: $e');
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
      
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());
      
      return userCredential.user;
    } catch (e) {
      throw e;
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
      print('✅ New Google user created in Firestore: ${user.uid}');
    } else {
      // Update last login for existing user
      await _firestore.collection('users').doc(user.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      print('✅ Existing Google user updated: ${user.uid}');
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
    print('🔄 FirebaseAuthService: Starting sign-out');

    // 1. Cache user ID BEFORE sign out
    final user = _auth.currentUser;
    final userId = user?.uid;

    // 2. Sign out from Google (only if user used Google)
    try {
      if (!kIsWeb && await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        print('🔵 Google sign-out complete');
      }
    } catch (e) {
      print('⚠️ Google sign-out error: $e');
    }

    // 3. Clean FCM token ONCE (AppAuthProvider will NOT duplicate)
 

    // 4. Sign out Firebase Auth
    await _auth.signOut();
    print('🟦 FirebaseAuth: Signed out');

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
      print('✅ FirebaseAuthService: Sign-out confirmed');
    }

  } catch (e) {
    print('❌ FirebaseAuthService sign-out error: $e');
    rethrow;
  }
}

// ===== NEW METHOD: Clean FCM tokens on logout =====
Future<void> _cleanFCMTokensOnLogout(String userId) async {
  try {
    print('🧹 Cleaning FCM tokens for user: $userId');
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!userDoc.exists) {
      print('⚠️ User document not found for token cleanup');
      return;
    }
    
    final userData = userDoc.data();
    final tokens = List<String>.from(userData?['fcmTokens'] ?? []);
    
    if (tokens.isEmpty) {
      print('✅ No FCM tokens to clean');
      return;
    }
    
    print('📱 Removing ${tokens.length} FCM tokens...');
    
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
        print('✅ Deactivated ${tokensSnapshot.docs.length} tokens in subcollection');
      }
    } catch (e) {
      print('⚠️ Error cleaning subcollection: $e');
    }
    
    print('✅ FCM tokens cleaned successfully');
    
  } catch (e) {
    print('❌ Error in _cleanFCMTokensOnLogout: $e');
    throw e;
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
  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        print('✅ User data retrieved from Firestore');
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }
// Add this method to your FirebaseAuthService class
Future<void> sendPasswordResetEmail(String email) async {
  try {
    print('🔄 Sending password reset email to: $email');
    await _auth.sendPasswordResetEmail(email: email);
    print('✅ Password reset email sent successfully');
  } on FirebaseAuthException catch (e) {
    print('❌ Password reset error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    print('❌ Unexpected error in password reset: $e');
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
    
    print('✅ Password changed successfully');
    return true;
  } on FirebaseAuthException catch (e) {
    print('❌ Password change error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    print('❌ Unexpected error in password change: $e');
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
    print('❌ Reauthentication error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    print('❌ Unexpected error in reauthentication: $e');
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
    print('✅ Password updated successfully');
    return true;
  } on FirebaseAuthException catch (e) {
    print('❌ Password update error: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  } catch (e) {
    print('❌ Unexpected error in password update: $e');
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