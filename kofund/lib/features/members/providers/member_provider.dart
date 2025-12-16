// lib/features/members/providers/member_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // For min() function
import '../../../core/services/user_service.dart';
import '../../../core/services/participant_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/providers/app_auth_provider.dart';

class MemberProvider with ChangeNotifier {
  final UserService _userService;
  final AppAuthProvider _authProvider;
  final ParticipantService _participantService;
  final ContributionService _contributionService;

  bool _isLoading = false;
  String? _error;
  List<UserModel> _members = [];
  UserModel? _selectedMember;

  // ✅ ADDED: Member history properties
  List<Map<String, dynamic>> _memberParticipationHistory = [];
  List<Map<String, dynamic>> _memberContributionHistory = [];
  bool _loadingMemberHistory = false;

  MemberProvider({
    required UserService userService,
    required AppAuthProvider authProvider,
    required ParticipantService participantService,
    required ContributionService contributionService,
  })  : _userService = userService,
        _authProvider = authProvider,
        _participantService = participantService,
        _contributionService = contributionService;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserModel> get members => _members;
  UserModel? get selectedMember => _selectedMember;

  // ✅ ADDED: Member history getters
  List<Map<String, dynamic>> get memberParticipationHistory => _memberParticipationHistory;
  List<Map<String, dynamic>> get memberContributionHistory => _memberContributionHistory;
  bool get loadingMemberHistory => _loadingMemberHistory;
void resetForNewUser() {
  _members = [];
  _selectedMember = null;
  _error = null;
  _memberParticipationHistory = [];
  _memberContributionHistory = [];
  _loadingMemberHistory = false;
  _isLoading = false;
  _safeNotifyListeners();
  print('🔄 MemberProvider: Reset for new user - all data cleared');
}
// In your MemberProvider class (lib/features/members/providers/member_provider.dart)

void clearDataForUserChange() {
  _members = [];
  _selectedMember = null;
  _error = null;
  _memberParticipationHistory = [];
  _memberContributionHistory = [];
  _loadingMemberHistory = false;
  _isLoading = false;
  _safeNotifyListeners();
  print('🔄 MemberProvider: Data cleared for user change');
}
// In lib/features/profile/providers/profile_provider.dart
// Add this method:
void clearAllData() {
  _isLoading = false;
  _members.clear();
  _error = null;
  notifyListeners();
  print('✅ ProfileProvider: All data cleared');
}
void refreshForUser(String? communityId) {
  if (communityId == null || communityId.isEmpty) {
    clearDataForUserChange();
    return;
  }
  
  clearDataForUserChange();
  print('✅ MemberProvider: Refreshing for community $communityId');
  
  // Load members for the new community
  loadApprovedMembers();
}
  // ✅ FASTER METHOD: Use injected _authProvider directly
  Future<void> loadApprovedMembers() async {
    final user = _authProvider.user; // ✅ Direct access - FASTER
    print('🔍 DEBUG: Current user - UID: ${user?.uid}, Community: ${user?.communityId}, Approved: ${user?.isApproved}');
      if (user == null) {
    _members = [];
    _safeNotifyListeners();
    return;
  }
    if (user?.communityId == null) {
      _setError('No community found');
      print('❌ DEBUG: No communityId found for current user');
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      print('🔄 DEBUG: Loading members for community: ${user!.communityId}');
      
      // Get all users in the community
      final allUsers = await _userService.getUsersByCommunity(user.communityId!);
      
      print('📊 DEBUG: Found ${allUsers.length} total users in community');
      
      // Debug: Print all users found
      for (var user in allUsers) {
        print('👥 DEBUG User: ${user.displayName} | UID: ${user.uid} | Approved: ${user.isApproved} | Community: ${user.communityId}');
      }
      
      // Filter only approved members
      _members = allUsers.where((user) => user.isApproved == true).toList();
      
      print('✅ DEBUG: Found ${_members.length} approved members after filtering');
      
      // Sort by display name
      _members.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
      
      notifyListeners();
    } catch (e) {
      print('❌ DEBUG: Error loading members: $e');
      _setError('Failed to load members: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ✅ GET MEMBER BY ID
  Future<UserModel?> getMemberById(String uid) async {
    try {
      print('🔄 MemberProvider: Getting member by ID: $uid');
      final user = await _userService.getUserById(uid);
      print('✅ MemberProvider: Found member: ${user?.displayName}');
      return user;
    } catch (e) {
      print('❌ MemberProvider Error getting member by ID: $e');
      _setError('Failed to load member details: $e');
      return null;
    }
  }

  // ✅ SET SELECTED MEMBER (for details screen)
  void setSelectedMember(UserModel member) {
    _selectedMember = member;
    notifyListeners();
  }

  // ✅ CLEAR SELECTED MEMBER
  void clearSelectedMember() {
    _selectedMember = null;
    notifyListeners();
  }

  void _safeNotifyListeners() {
    Future.microtask(() {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

Future<void> fetchMemberParticipationHistory(String memberId) async {
  print('🎯 MemberProvider: Starting to fetch participation history for member: $memberId');
  
  _loadingMemberHistory = true;
  _safeNotifyListeners();

  try {
    final startTime = DateTime.now();
    
    // ✅ Store the result in the local variable
    final result = await _participantService.getMemberParticipationHistory(memberId);
    _memberParticipationHistory = result;
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    
    print('✅ MemberProvider: Loaded ${_memberParticipationHistory.length} participations in ${duration.inMilliseconds}ms');
    
    // Debug: Print first few participations if available
    if (_memberParticipationHistory.isNotEmpty) {
      print('📋 Sample participation data:');
      for (int i = 0; i < min(2, _memberParticipationHistory.length); i++) {
        print('   ${i+1}. ${_memberParticipationHistory[i]}');
      }
    } else {
      print('⚠️ MemberProvider: No participations found for member $memberId');
    }
    
  } catch (e) {
    print('❌ MemberProvider Error fetching participation history: $e');
    _memberParticipationHistory = [];
    _setError('Failed to load participation history: $e');
  } finally {
    _loadingMemberHistory = false;
    _safeNotifyListeners(); // ✅ Make sure to notify listeners
  }
}

Future<void> fetchMemberContributionHistory(String memberId) async {
  print('💰 MemberProvider: Starting to fetch contribution history for member: $memberId');
  
  _loadingMemberHistory = true;
  _safeNotifyListeners();

  try {
    final startTime = DateTime.now();
    
    // ✅ Store the result in the local variable
    final result = await _contributionService.getMemberContributionHistory(memberId);
    _memberContributionHistory = result;
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    
    print('✅ MemberProvider: Loaded ${_memberContributionHistory.length} contributions in ${duration.inMilliseconds}ms');
    
    // Debug: Print first few contributions if available
    if (_memberContributionHistory.isNotEmpty) {
      print('📋 Sample contribution data:');
      for (int i = 0; i < min(2, _memberContributionHistory.length); i++) {
        print('   ${i+1}. ${_memberContributionHistory[i]}');
      }
    } else {
      print('⚠️ MemberProvider: No contributions found for member $memberId');
    }
    
  } catch (e) {
    print('❌ MemberProvider Error fetching contribution history: $e');
    _memberContributionHistory = [];
    _setError('Failed to load contribution history: $e');
  } finally {
    _loadingMemberHistory = false;
    _safeNotifyListeners(); // ✅ Make sure to notify listeners
  }
}



Future<void> loadMemberHistoryData(String memberId) async {
  print('🔄 MemberProvider: Starting to load ALL history for member: $memberId');
  
  _loadingMemberHistory = true;
  _safeNotifyListeners();

  try {
    // Clear previous data
    _memberParticipationHistory = [];
    _memberContributionHistory = [];
    
    print('📊 MemberProvider: Loading participation history...');
    
    // ✅ FIX 1: Use await to ensure completion
    await fetchMemberParticipationHistory(memberId);
    
    print('📊 MemberProvider: Participation history loaded. Count: ${_memberParticipationHistory.length}');
    
    print('📊 MemberProvider: Loading contribution history...');
    
    // ✅ FIX 2: Use await to ensure completion  
    await fetchMemberContributionHistory(memberId);
    
    print('📊 MemberProvider: Contribution history loaded. Count: ${_memberContributionHistory.length}');
    
    print('✅ MemberProvider: Successfully loaded all member history data');
    print('   - Participations: ${_memberParticipationHistory.length} items');
    print('   - Contributions: ${_memberContributionHistory.length} items');
    
    // ✅ FIX 3: Force notify listeners after both are done
    _safeNotifyListeners();
    
  } catch (e) {
    print('❌ MemberProvider Error loading member history data: $e');
    print('❌ Stack trace: ${e.toString()}');
    _setError('Failed to load member history: $e');
  } finally {
    _loadingMemberHistory = false;
    _safeNotifyListeners();
  }
}

  // ✅ CLEAR MEMBER HISTORY DATA
  void clearMemberHistoryData() {
    _memberParticipationHistory = [];
    _memberContributionHistory = [];
    _loadingMemberHistory = false;
    notifyListeners();
  }

  // ✅ DEBUG FIRESTORE STRUCTURE METHOD
  Future<void> debugFirestoreStructure(String memberId) async {
    print('\n🔍🔍🔍 DEBUG FIRESTORE STRUCTURE FOR MEMBER: $memberId 🔍🔍🔍');
    
    try {
      // 1. Check if user exists
      final user = await _userService.getUserById(memberId);
      if (user == null) {
        print('❌ User $memberId does not exist in users collection');
        return;
      }
      print('✅ User found: ${user.displayName} (${user.email})');
      print('   Community: ${user.communityId}, Approved: ${user.isApproved}, Admin: ${user.isAdmin}');
      
      // 2. Check participants collection
      print('\n🎯 Checking participants collection...');
      try {
        final participantsSnapshot = await FirebaseFirestore.instance
            .collection('participants')
            .where('userId', isEqualTo: memberId)
            .get();
        
        print('   Total participant documents: ${participantsSnapshot.docs.length}');
        for (final doc in participantsSnapshot.docs) {
          final data = doc.data();
          print('   👤 Participant: ${doc.id}');
          print('      ProgramId: ${data['programId']}');
          print('      Status: ${data['status']}');
          print('      JoinedAt: ${data['joinedAt']}');
        }
      } catch (e) {
        print('❌ Error checking participants: $e');
      }
      
      // 3. Check contributions collection
      print('\n💰 Checking contributions collection...');
      try {
        final contributionsSnapshot = await FirebaseFirestore.instance
            .collection('contributions')
            .where('userId', isEqualTo: memberId)
            .get();
        
        print('   Total contribution documents: ${contributionsSnapshot.docs.length}');
        for (final doc in contributionsSnapshot.docs) {
          final data = doc.data();
          print('   💳 Contribution: ${doc.id}');
          print('      ProgramId: ${data['programId']}');
          print('      Amount: ${data['amount']}');
          print('      Status: ${data['status']}');
          print('      PaymentMethod: ${data['paymentMethod']}');
        }
      } catch (e) {
        print('❌ Error checking contributions: $e');
      }
      
      // 4. Check programs collection (first 3 to verify structure)
      print('\n📋 Checking programs collection structure...');
      try {
        final programsSnapshot = await FirebaseFirestore.instance
            .collection('programs')
            .limit(3)
            .get();
        
        print('   Sample programs (${programsSnapshot.docs.length}):');
        for (final doc in programsSnapshot.docs) {
          final data = doc.data();
          print('   📅 Program: ${doc.id} - ${data['title']}');
          print('      Type: ${data['programType']}');
          print('      Suggested: ${data['suggestedContribution']}');
        }
      } catch (e) {
        print('❌ Error checking programs: $e');
      }
      
      print('\n🔍🔍🔍 END OF DEBUG 🔍🔍🔍\n');
      
    } catch (e) {
      print('❌❌❌ CRITICAL ERROR in debugFirestoreStructure: $e ❌❌❌');
    }
  }

  // ✅ UPDATE USER ROLE (Make Admin / Remove Admin)
  Future<bool> updateMemberRole(String uid, bool makeAdmin) async {
    final currentUser = _authProvider.user; // ✅ Direct access
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can update user roles');
      return false;
    }

    _setLoading(true);
    try {
      await _userService.updateUserRole(uid, makeAdmin);
      
      // Update local state
      final index = _members.indexWhere((member) => member.uid == uid);
      if (index != -1) {
        _members[index] = _members[index].copyWith(
          isAdmin: makeAdmin,
          role: makeAdmin ? 'admin' : 'member',
        );
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to update user role: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ✅ UNAPPROVE USER
  Future<bool> unapproveUser(String uid) async {
    final currentUser = _authProvider.user; // ✅ Direct access
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can unapprove users');
      return false;
    }

    _setLoading(true);
    try {
      await _userService.unapproveUser(uid);
      
      // Remove from local list (since we only show approved users)
      _members.removeWhere((member) => member.uid == uid);
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to unapprove user: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

Future<bool> removeFromCommunity(String uid) async {
  final currentUser = _authProvider.user;
  if (currentUser == null || !currentUser.isAdmin) {
    _setError('Only admins can remove users from community');
    return false;
  }

  _setLoading(true);
  try {
    // ✅ FIXED: Add communityId parameter
final communityId = currentUser.communityId;
if (communityId == null || communityId.isEmpty) {
  _setError('No community found');
  _setLoading(false);
  return false;
}

await _userService.removeFromCommunity(uid, communityId);

    
    // Remove from local list
    _members.removeWhere((member) => member.uid == uid);
    
    notifyListeners();
    return true;
  } catch (e) {
    _setError('Failed to remove user from community: $e');
    return false;
  } finally {
    _setLoading(false);
  }
}
  // ✅ BULK UPDATE MEMBER ROLES
  Future<bool> bulkUpdateMemberRoles(List<String> uids, bool makeAdmin) async {
    final currentUser = _authProvider.user; // ✅ Direct access
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can update user roles');
      return false;
    }

    _setLoading(true);
    try {
      // Update each user individually
      for (final uid in uids) {
        await _userService.updateUserRole(uid, makeAdmin);
      }
      
      // Update local state
      for (final uid in uids) {
        final index = _members.indexWhere((member) => member.uid == uid);
        if (index != -1) {
          _members[index] = _members[index].copyWith(
            isAdmin: makeAdmin,
            role: makeAdmin ? 'admin' : 'member',
          );
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update user roles: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ✅ BULK UNAPPROVE USERS
  Future<bool> bulkUnapproveUsers(List<String> uids) async {
    final currentUser = _authProvider.user; // ✅ Direct access
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can unapprove users');
      return false;
    }

    _setLoading(true);
    try {
      // Unapprove each user individually
      for (final uid in uids) {
        await _userService.unapproveUser(uid);
      }
      
      // Remove from local list
      _members.removeWhere((member) => uids.contains(member.uid));
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to unapprove users: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ✅ BULK REMOVE FROM COMMUNITY
  Future<bool> bulkRemoveFromCommunity(List<String> uids) async {
    final currentUser = _authProvider.user; // ✅ Direct access
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can remove users from community');
      return false;
    }

    _setLoading(true);
    try {
      // Remove each user individually
      for (final uid in uids) {
final communityId = _authProvider.user?.communityId;
if (communityId == null || communityId.isEmpty) {
  _setError('No community found');
  _setLoading(false);
  return false;
}
await _userService.removeFromCommunity(uid, communityId);

      }
      
      // Remove from local list
      _members.removeWhere((member) => uids.contains(member.uid));
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to remove users from community: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ✅ SEARCH MEMBERS
  List<UserModel> searchMembers(String query) {
    if (query.isEmpty) return _members;
    
    return _members.where((member) {
      final name = member.displayName?.toLowerCase() ?? '';
      final email = member.email?.toLowerCase() ?? '';
      final searchTerm = query.toLowerCase();
      
      return name.contains(searchTerm) || email.contains(searchTerm);
    }).toList();
  }

  // ✅ FASTER REFRESH: No context parameter needed
  Future<void> refreshMembers() async {
    await loadApprovedMembers(); // ✅ No context parameter
  }

  // ✅ GET MEMBER STATISTICS
  Map<String, dynamic> getMemberStatistics(String memberId) {
    final participations = _memberParticipationHistory.length;
    final contributions = _memberContributionHistory.length;
    
    final totalContributed = _memberContributionHistory.fold(0.0, (sum, c) => sum + (c['amount'] ?? 0.0));
    final paidParticipations = _memberParticipationHistory.where((p) => p['hasPaidContribution'] == true).length;

    return {
      'totalParticipations': participations,
      'totalContributions': contributions,
      'totalAmountContributed': totalContributed,
      'paidParticipations': paidParticipations,
      'participationRate': participations > 0 ? (paidParticipations / participations) * 100 : 0,
      'averageContribution': contributions > 0 ? totalContributed / contributions : 0,
    };
  }

  // Helper methods
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
    notifyListeners();
  }
}