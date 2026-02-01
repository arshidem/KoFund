import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:kofund/features/contributions/providers/contribution_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';
import 'package:flutter/material.dart';
class ProfileProvider with ChangeNotifier {
  final ProgramProvider _programProvider;
  final ContributionProvider _contributionProvider;
  final UserService _userService;
  final ParticipantService _participantService;
  final AppAuthProvider _authProvider;

  bool _isLoading = false;
  String? _error;
  bool _isDisposed = false;

  // Track which user's data we have loaded
  String? _loadedUserId;
  
  // Local caches for participation and contribution history
  List<Map<String, dynamic>> _participationHistory = [];
  List<Map<String, dynamic>> _contributionHistory = [];

  ProfileProvider({
    required ProgramProvider programProvider,
    required ContributionProvider contributionProvider,
    required ParticipantService participantService,
    required AppAuthProvider authProvider,
    required UserService userService,
  })  : _programProvider = programProvider,
        _contributionProvider = contributionProvider,
        _participantService = participantService,
        _authProvider = authProvider,
        _userService = userService;

  // Public getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get participationHistory => _participationHistory;
  List<Map<String, dynamic>> get contributionHistory => _contributionHistory;
  
  // Get current user from FirebaseAuth
  User? get currentUser => FirebaseAuth.instance.currentUser;
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Check if data belongs to current user using FirebaseAuth
  bool get isDataForCurrentUser {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final result = firebaseUser != null && 
                  _loadedUserId == firebaseUser.uid;
    
    debugPrint('🔍 DEBUG isDataForCurrentUser:');
    debugPrint('🔍   FirebaseAuth.currentUser?.uid: ${firebaseUser?.uid}');
    debugPrint('🔍   _loadedUserId: $_loadedUserId');
    debugPrint('🔍   Result: $result');
    
    return result;
  }

// In ProfileProvider class
String? getUserProviderType() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.providerData.isEmpty) return null;
  
  if (user.providerData.any((info) => info.providerId == 'google.com')) {
    return 'google';
  }
  
  if (user.providerData.any((info) => info.providerId == 'password')) {
    return 'email';
  }
  
  return 'other';
}
  // Safe notify listeners
  void _safeNotifyListeners() {
    if (!_isDisposed && hasListeners) {
      notifyListeners();
    }
  }

  // Clear all user data
  void clearAllUserData() {
    _loadedUserId = null;
    _participationHistory.clear();
    _contributionHistory.clear();
    _error = null;
    _isLoading = false;
    
    _safeNotifyListeners();
    debugPrint('🔄 ProfileProvider: All user data cleared');
  }

  // Compatibility method
  void clearAllData() {
    clearAllUserData();
  }

  // ✅ UPDATE USER PROFILE - FIXED VERSION
  Future<bool> updateUserProfile({
    String? name,
    String? phoneNumber,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      debugPrint('Updating user in Firestore...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('User updated successfully in Firestore');
      
      _isLoading = false;
      _safeNotifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error updating user: $e');
      _error = 'Failed to update profile: $e';
      _isLoading = false;
      _safeNotifyListeners();
      
      return false;
    }
  }

  // ✅ UPDATE PRIVACY SETTINGS - FIXED VERSION
  Future<bool> updatePrivacySettings(bool showDetailedProfile) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      await _userService.updateUserPrivacySettings(
        currentUser.uid, 
        showDetailedProfile
      );

      // No need to refresh auth provider here since we're not using it
      // The changes will be reflected when user data is reloaded
      
      _isLoading = false;
      _safeNotifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error updating privacy settings: $e');
      _error = 'Failed to update privacy settings: $e';
      _isLoading = false;
      _safeNotifyListeners();
      
      return false;
    }
  }

Future<bool> deleteUserAccount({String? password}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('❌ No authenticated user found');
    _setError('No authenticated user found.');
    return false;
  }

  debugPrint('🚀 Starting account deletion for user: ${user.uid}');
  _setLoading(true);

  try {
    final userId = user.uid;
    final providerType = getUserProviderType();
    
    debugPrint('👤 Provider type: $providerType');

    // For email/password users, reauthenticate if password is provided
    if (providerType == 'email' && password != null && password.isNotEmpty) {
      debugPrint('🔐 Reauthenticating email/password user...');
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        debugPrint('✅ Reauthentication successful');
      } on FirebaseAuthException catch (authError) {
        _setLoading(false);
        
        // Handle wrong password error
        if (authError.code == 'wrong-password' || 
            authError.code == 'invalid-credential') {
          throw Exception('wrong_password'); // Special exception for wrong password
        }
        
        // Re-throw for other auth errors
        rethrow;
      }
    }
    // For Google users, we'll handle reauthentication differently
    else if (providerType == 'google') {
      debugPrint('🔗 Google user detected - will require reauthentication');
    }

    // 🔹 Step 1: Delete from Firestore 'users' collection
    debugPrint('🗑️ Deleting from Firestore users collection...');
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    debugPrint('✅ Firestore users deleted');

    // 🔹 Step 2: Delete from community members subcollection (if exists)
    debugPrint('🗑️ Deleting from communities...');
    await _deleteUserFromCommunities(userId);
    debugPrint('✅ Communities cleaned up');

    // 🔹 Step 3: Delete from Firebase Authentication
    debugPrint('🗑️ Deleting from Firebase Auth...');
    await user.delete();
    debugPrint('✅ Firebase Auth user deleted');

    // 🔹 Step 4: Sign out
    debugPrint('👋 Signing out...');
    await FirebaseAuth.instance.signOut();
    debugPrint('✅ Signed out');

    _setLoading(false);
    debugPrint('🎉 Account deletion COMPLETE');
    return true;
    
  } on FirebaseAuthException catch (e) {
    debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
    _setLoading(false);
    
    if (e.code == 'requires-recent-login') {
      final providerType = getUserProviderType();
      
      if (providerType == 'google') {
        _setError(
          'For security, please sign out and sign in again with Google, '
          'then delete your account immediately.',
        );
      } else if (providerType == 'email') {
        _setError(
          'Please re-enter your password to confirm account deletion.',
        );
        // Return special code to indicate password is needed
        throw Exception('password_required');
      }
    } else {
      _setError('Auth Error: ${e.message}');
    }
    return false;
  } on Exception catch (e) {
    // Handle wrong password exception
    if (e.toString().contains('wrong_password')) {
      _setLoading(false);
      throw Exception('wrong_password'); // Re-throw to handle in UI
    }
    
    // Handle password required exception
    if (e.toString().contains('password_required')) {
      _setLoading(false);
      throw Exception('password_required');
    }
    
    debugPrint('❌ General error: $e');
    _setError('Failed to delete account: $e');
    _setLoading(false);
    return false;
  } catch (e) {
    debugPrint('❌ General error: $e');
    if (e.toString().contains('password_required') || 
        e.toString().contains('wrong_password')) {
      rethrow; // Re-throw to handle in UI
    }
    _setError('Failed to delete account: $e');
    _setLoading(false);
    return false;
  }
}
// Helper method to delete user from community members subcollection
Future<void> _deleteUserFromCommunities(String userId) async {
  try {
    // Assuming your structure is: communities/{communityId}/members/{userId}
    // We need to find all communities where this user is a member
    
    // Method 1: If you have a collection of communities
    final communitiesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .where('members.$userId', isNotEqualTo: null)
        .get();

    // Delete user from each community's members subcollection
    final batch = FirebaseFirestore.instance.batch();
    
    for (final doc in communitiesSnapshot.docs) {
      final memberRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(doc.id)
          .collection('members')
          .doc(userId);
      
      batch.delete(memberRef);
    }
    
    if (communitiesSnapshot.docs.isNotEmpty) {
      await batch.commit();
    }
    
  } catch (e) {
    debugPrint('Error deleting user from communities: $e');
    // Don't throw error here, continue with account deletion
  }
}

Future<bool> leaveCommunity() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return false;

  _setLoading(true);
  try {
    // Get communityId from user document directly
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final communityId = userDoc.data()?['communityId'] as String?;

    if (communityId == null || communityId.isEmpty) {
      _setError('You are not in any community');
      _setLoading(false);
      return false;
    }

    // ---- FIXED: pass actual uid and communityId ----
    final uid = currentUser.uid;
    await _userService.leaveCommunity(uid, communityId);
    // ------------------------------------------------

    // Clear local data since user left community
    clearAllUserData();

    _setLoading(false);
    return true;
  } catch (e) {
    _setError('Failed to leave community: $e');
    _setLoading(false);
    return false;
  }
}

  Future<void> loadUserStatistics({String? userId}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No Firebase user');
      return;
    }

    // Get user data from Firestore to get communityId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists || userDoc.data() == null) {
      debugPrint('❌ No user data in Firestore');
      return;
    }
    
    final userData = userDoc.data()!;
    final communityId = userData['communityId'];
    
    if (communityId == null) {
      debugPrint('❌ User has no community');
      return;
    }

    // Use the userId parameter if provided, otherwise use current user
    final targetUserId = userId ?? currentUser.uid;
    
    debugPrint('👤 Loading statistics for target user: $targetUserId');
    debugPrint('👤 Current Firebase user: ${currentUser.uid}');
    debugPrint('👤 Are they the same? ${targetUserId == currentUser.uid}');
    
    _setLoading(true);
    try {
      await Future.wait([
        _programProvider.loadMyParticipations(targetUserId, communityId),
        _contributionProvider.loadUserContributions(targetUserId, communityId),
      ]);
      
      _loadedUserId = targetUserId;
      debugPrint('✅ Statistics loaded for user: $targetUserId');
      debugPrint('✅ _loadedUserId set to: $_loadedUserId');
      
    } catch (e) {
      _setError('Failed to load user statistics: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getUserParticipationHistory({String? userId}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No Firebase user');
      return;
    }

    // Use the userId parameter if provided, otherwise use current user
    final targetUserId = userId ?? currentUser.uid;
    
    debugPrint('🎯 Getting participation history for: $targetUserId');
    debugPrint('🎯 Current Firebase user: ${currentUser.uid}');

    _setLoading(true);
    try {
      _participationHistory = await _participantService.getUserParticipationHistoryWithContributions(targetUserId);
      _loadedUserId = targetUserId;
      debugPrint('✅ Loaded ${_participationHistory.length} participations');
      debugPrint('✅ _loadedUserId set to: $_loadedUserId');
    } catch (e) {
      debugPrint('❌ Failed to load participation history: $e');
      _setError('Failed to load participation history: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get user contribution history
  Future<void> getUserContributionHistory({String? userId}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No Firebase user');
      return;
    }

    // Get user data from Firestore to get communityId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists || userDoc.data() == null) {
      debugPrint('❌ No user data in Firestore');
      return;
    }
    
    final userData = userDoc.data()!;
    final communityId = userData['communityId'];
    
    if (communityId == null) {
      debugPrint('❌ User has no community');
      return;
    }

    // Use the userId parameter if provided, otherwise use current user
    final targetUserId = userId ?? currentUser.uid;
    
    debugPrint('💰 Getting contribution history for: $targetUserId');
    debugPrint('💰 Current Firebase user: ${currentUser.uid}');

    _setLoading(true);
    try {
      final result = await _contributionProvider.getUserPaymentHistoryWithDetails(
        targetUserId,
        communityId,
      );
      
      _contributionHistory = result;
      _loadedUserId = targetUserId;
      debugPrint('✅ Loaded ${_contributionHistory.length} contributions');
      debugPrint('✅ _loadedUserId set to: $_loadedUserId');
    } catch (e) {
      _setError('Failed to load contribution history: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get user statistics
  Map<String, dynamic> getUserStatistics() {
    // Check if we have data loaded at all
    if (_participationHistory.isEmpty && _contributionHistory.isEmpty) {
      debugPrint('⚠️ No data loaded yet');
      return {
        'participations': 0,
        'contributions': 0,
        'totalContributed': 0.0,
        'averageContribution': 0.0,
        'paidParticipations': 0,
        'pendingParticipations': 0,
      };
    }

    final participations = _participationHistory.length;
    final contributions = _contributionHistory.length;
    
    final totalContributedFromParticipations = _participationHistory
        .fold(0.0, (sum, p) => sum + (p['contributionPaid'] ?? 0.0));

    final totalContributedFromContributions = _contributionHistory
        .fold(0.0, (sum, c) => sum + (c['amount'] ?? 0.0));

    return {
      'participations': participations,
      'contributions': contributions,
      'totalContributed': totalContributedFromParticipations,
      'totalContributedFromContributions': totalContributedFromContributions,
      'averageContribution': contributions > 0 ? totalContributedFromContributions / contributions : 0.0,
      'paidParticipations': _participationHistory.where((p) => p['hasPaidContribution'] == true).length,
      'pendingParticipations': _participationHistory.where((p) => p['hasPaidContribution'] == false).length,
    };
  }

  // ✅ GET USER CONTRIBUTION SUMMARY
  Map<String, dynamic> getUserContributionSummary() {
    final contributions = _contributionProvider.userContributions;
    final totalAmount = contributions.fold(0.0, (sum, c) => sum + c.amount);
    final averageAmount = contributions.isNotEmpty ? totalAmount / contributions.length : 0.0;
    
    final paymentMethodBreakdown = <String, double>{};
    for (final contribution in contributions) {
      paymentMethodBreakdown[contribution.paymentMethod] = 
          (paymentMethodBreakdown[contribution.paymentMethod] ?? 0) + contribution.amount;
    }

    final monthlyBreakdown = <String, double>{};
    for (final contribution in contributions) {
      final monthKey = '${contribution.createdAt.toDate().year}-${contribution.createdAt.toDate().month}';
      monthlyBreakdown[monthKey] = 
          (monthlyBreakdown[monthKey] ?? 0) + contribution.amount;
    }

    return {
      'totalContributions': contributions.length,
      'totalAmount': totalAmount,
      'averageAmount': averageAmount,
      'paymentMethodBreakdown': paymentMethodBreakdown,
      'monthlyBreakdown': monthlyBreakdown,
      'lastContributionDate': contributions.isNotEmpty 
          ? contributions.first.createdAt 
          : null,
    };
  }

  // ✅ GET USER ACTIVITY SUMMARY WITH REAL-TIME DATA
  Map<String, dynamic> getUserActivitySummary() {
    final stats = getUserStatistics();
    final contributionSummary = getUserContributionSummary();
    
    final totalPrograms = _programProvider.programs.length;
    final userParticipations = _participationHistory.length;
    final participationRate = totalPrograms > 0 ? userParticipations / totalPrograms : 0.0;

    return {
      'participationRate': participationRate,
      'totalProgramsJoined': userParticipations,
      'totalContributions': stats['contributions'],
      'totalAmountContributed': stats['totalContributed'],
      'paidParticipations': stats['paidParticipations'],
      'pendingParticipations': stats['pendingParticipations'],
      'contributionFrequency': _calculateContributionFrequency(),
      'activeMonths': contributionSummary['monthlyBreakdown'].length,
    };
  }

  // ✅ GET PARTICIPATION SUMMARY
  Map<String, dynamic> getParticipationSummary() {
    final paidCount = _participationHistory.where((p) => p['hasPaidContribution'] == true).length;
    final pendingCount = _participationHistory.where((p) => p['hasPaidContribution'] == false).length;
    final totalPaid = _participationHistory.fold(0.0, (sum, p) => sum + (p['contributionPaid'] ?? 0.0));
    final totalSuggested = _participationHistory.fold(0.0, (sum, p) => sum + (p['suggestedContribution'] ?? 0.0));
    final completionRate = totalSuggested > 0 ? (totalPaid / totalSuggested) * 100 : 0;

    return {
      'totalParticipations': _participationHistory.length,
      'paidParticipations': paidCount,
      'pendingParticipations': pendingCount,
      'totalPaid': totalPaid,
      'totalSuggested': totalSuggested,
      'completionRate': completionRate,
      'paymentRate': _participationHistory.length > 0 ? (paidCount / _participationHistory.length) * 100 : 0,
    };
  }

  // ✅ CALCULATE CONTRIBUTION FREQUENCY
  double _calculateContributionFrequency() {
    final contributions = _contributionProvider.userContributions;
    if (contributions.length < 2) return 0.0;

    final sortedContributions = List<ContributionModel>.from(contributions)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    int totalDays = 0;
    for (int i = 1; i < sortedContributions.length; i++) {
      final previous = sortedContributions[i - 1].createdAt.toDate();
      final current = sortedContributions[i].createdAt.toDate();
      final difference = current.difference(previous).inDays;
      totalDays += difference;
    }

    return totalDays / (sortedContributions.length - 1);
  }

  // ✅ REFRESH ALL USER DATA
  Future<void> refreshAllUserData({String? userId}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No Firebase user');
      return;
    }

    // Get user data from Firestore to get communityId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists || userDoc.data() == null) {
      debugPrint('❌ No user data in Firestore');
      return;
    }
    
    final userData = userDoc.data()!;
    final communityId = userData['communityId'];
    
    if (communityId == null) {
      debugPrint('❌ User has no community');
      return;
    }

    final targetUserId = userId ?? currentUser.uid;

    _setLoading(true);
    try {
      await Future.wait([
        getUserParticipationHistory(userId: targetUserId),
        getUserContributionHistory(userId: targetUserId),
      ]);
      
      // Also refresh program and contribution providers
      await Future.wait([
        _programProvider.loadMyParticipations(targetUserId, communityId),
        _contributionProvider.loadUserContributions(targetUserId, communityId),
      ]);
      
    } catch (e) {
      _setError('Failed to refresh user data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ✅ GET RECENT ACTIVITY
  List<Map<String, dynamic>> getRecentActivity({int limit = 10}) {
    final List<Map<String, dynamic>> recentActivity = [];

    for (final participation in _participationHistory.take(limit ~/ 2)) {
      recentActivity.add({
        'type': 'participation',
        'title': participation['programTitle'],
        'date': participation['joinedAt'],
        'description': 'Joined program',
        'icon': Icons.event_available,
      });
    }

    for (final contribution in _contributionHistory.take(limit ~/ 2)) {
      recentActivity.add({
        'type': 'contribution',
        'title': contribution['programTitle'],
        'date': contribution['createdAt'],
        'description': 'Contributed ₹${contribution['amount']}',
        'icon': Icons.payments,
      });
    }

    recentActivity.sort((a, b) {
      final dateA = a['date'] is Timestamp ? a['date'].toDate() : a['date'] as DateTime;
      final dateB = b['date'] is Timestamp ? b['date'].toDate() : b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    return recentActivity.take(limit).toList();
  }

  // ✅ HELPERS WITH SAFE NOTIFICATION
  void _setLoading(bool value) {
    _isLoading = value;
    _safeNotifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _isLoading = false;
    _safeNotifyListeners();
  }

  void clearError() {
    _error = null;
    _safeNotifyListeners();
  }

  void clearHistories() {
    _participationHistory = [];
    _contributionHistory = [];
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

