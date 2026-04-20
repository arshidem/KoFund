// lib/features/members/providers/member_provider.dart
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

import '../../../core/services/user_service.dart';
import '../../../core/services/participant_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../../core/services/virtual_user_service.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/providers/app_auth_provider.dart';

class MemberProvider with ChangeNotifier {
  final UserService _userService;
  final AppAuthProvider _authProvider;
  final ParticipantService _participantService;
  final ContributionService _contributionService;
  final VirtualUserService _virtualUserService;

  // Loading states
  bool _isLoading = false;
  String? _error;
  
  // Data
  List<UserModel> _members = [];
  UserModel? _selectedMember;
  
  // Member history
  List<Map<String, dynamic>> _memberParticipationHistory = [];
  List<Map<String, dynamic>> _memberContributionHistory = [];
  bool _loadingMemberHistory = false;
  
  // Filter
  String _currentFilter = 'all';

  MemberProvider({
    required UserService userService,
    required AppAuthProvider authProvider,
    required ParticipantService participantService,
    required ContributionService contributionService,
    required VirtualUserService virtualUserService,
  })  : _userService = userService,
        _authProvider = authProvider,
        _participantService = participantService,
        _contributionService = contributionService,
        _virtualUserService = virtualUserService;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserModel> get members => _members;
  UserModel? get selectedMember => _selectedMember;
  
  // Member history getters
  List<Map<String, dynamic>> get memberParticipationHistory => _memberParticipationHistory;
  List<Map<String, dynamic>> get memberContributionHistory => _memberContributionHistory;
  bool get loadingMemberHistory => _loadingMemberHistory;

  // ==================== LOAD ALL MEMBERS ====================
/// Load all members at once (no pagination)
Future<void> loadMembers({String filterType = 'all', bool reset = false}) async {
  if (_isLoading) {
    developer.log('⏸️ MemberProvider: loadMembers skipped - already loading');
    return;
  }

  // ⭐ CACHE CHECK: Skip Firestore reads if data is already available
  if (!reset && _members.isNotEmpty && _currentFilter == filterType) {
    developer.log('⚡ MemberProvider: Returning ${_members.length} cached members');
    return;
  }
  
  final user = _authProvider.user;
  if (user == null || user.communityId == null) {
    developer.log('⚠️ MemberProvider: No user or community ID');
    _members = [];
    _safeNotifyListeners();
    return;
  }
  
  developer.log('🔄 MemberProvider: loadMembers called - filter: $filterType');
  
  _currentFilter = filterType;
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();
  
  try {
    final users = await _userService.getUsersByCommunity(
      user.communityId!,
      filterType: filterType,
    );
    
    developer.log('📥 MemberProvider: Received ${users.length} users');
    
    _members = users;
    
    // Sort alphabetically
    _members.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
    
    developer.log('✅ MemberProvider: Loaded ${_members.length} members (filter: $filterType)');
    
  } catch (e, stackTrace) {
    _error = 'Failed to load members: $e';
    developer.log('❌ MemberProvider Error: $e', error: e, stackTrace: stackTrace);
    _members = [];
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}

 

  // ==================== VIRTUAL USER METHODS ====================

  /// Delete a virtual user
  Future<bool> deleteVirtualUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      _safeNotifyListeners();
      
      developer.log('🗑️ MemberProvider: Deleting virtual user $userId');
      
      // First, get the user to check if they're virtual
      final user = await _userService.getUserById(userId);
      if (user == null) {
        throw Exception('User not found');
      }
      
      if (!user.isVirtualUser) {
        throw Exception('User is not a virtual user');
      }
      
      // Check if current user is admin
      final currentUser = _authProvider.user;
      if (currentUser == null || !currentUser.isAdmin) {
        throw Exception('Only admins can delete virtual users');
      }
      
      // Check if trying to delete self
      if (currentUser.uid == userId) {
        throw Exception('Cannot delete yourself');
      }
      
      // Use VirtualUserService to delete - FIXED: await properly
      await _virtualUserService.deleteVirtualUser(userId);
      
      // Remove from local members list
      _members.removeWhere((member) => member.uid == userId);
      
      // Also remove from selected member if it's the same user
      if (_selectedMember?.uid == userId) {
        _selectedMember = null;
      }
      
      developer.log('✅ MemberProvider: Successfully deleted virtual user $userId');
      
      return true; // Return true on success
      
    } catch (e) {
      _error = 'Failed to delete virtual user: $e';
      developer.log('❌ MemberProvider Error deleting virtual user: $e');
      return false; // Return false on error
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // ==================== CLEANUP METHODS ====================

  void resetForNewUser() {
    _members.clear();
    _selectedMember = null;
    _error = null;
    _memberParticipationHistory.clear();
    _memberContributionHistory.clear();
    _loadingMemberHistory = false;
    _isLoading = false;
    _currentFilter = 'all';
    developer.log('🔄 MemberProvider: Reset for new user');
  }

  void clearDataForUserChange() {
    _members.clear();
    _selectedMember = null;
    _error = null;
    _memberParticipationHistory.clear();
    _memberContributionHistory.clear();
    _loadingMemberHistory = false;
    _isLoading = false;
    _currentFilter = 'all';
    _safeNotifyListeners();
    developer.log('🔄 MemberProvider: Data cleared for user change');
  }

  void refreshForUser(String? communityId) {
    if (communityId == null || communityId.isEmpty) {
      clearDataForUserChange();
      return;
    }
    
    clearDataForUserChange();
    developer.log('✅ MemberProvider: Refreshing for community $communityId');
    loadMembers();
  }

  // ==================== MEMBER MANAGEMENT ====================

  /// Get member by ID
  Future<UserModel?> getMemberById(String uid) async {
    try {
      return await _userService.getUserById(uid);
    } catch (e) {
      _setError('Failed to load member details: $e');
      return null;
    }
  }

  /// Set selected member (for details screen)
  void setSelectedMember(UserModel member) {
    _selectedMember = member;
    _safeNotifyListeners();
  }

  /// Clear selected member
  void clearSelectedMember() {
    _selectedMember = null;
    _safeNotifyListeners();
  }

  // ==================== MEMBER HISTORY ====================

  Future<void> loadMemberHistoryData(String memberId) async {
    _loadingMemberHistory = true;
    _safeNotifyListeners();

    try {
      // Clear previous data
      _memberParticipationHistory.clear();
      _memberContributionHistory.clear();
      
      // Load both histories in parallel
      final futures = [
        _participantService.getMemberParticipationHistory(memberId),
        _contributionService.getMemberContributionHistory(memberId),
      ];
      
      final results = await Future.wait(futures);
      
      _memberParticipationHistory = results[0];
      _memberContributionHistory = results[1];
      
      developer.log('✅ MemberProvider: Loaded ${_memberParticipationHistory.length} participations, ${_memberContributionHistory.length} contributions');
      
    } catch (e) {
      _setError('Failed to load member history: $e');
      _memberParticipationHistory.clear();
      _memberContributionHistory.clear();
    } finally {
      _loadingMemberHistory = false;
      _safeNotifyListeners();
    }
  }

  Future<void> fetchMemberParticipationHistory(String memberId) async {
    _loadingMemberHistory = true;
    _safeNotifyListeners();

    try {
      _memberParticipationHistory = await _participantService.getMemberParticipationHistory(memberId);
    } catch (e) {
      _setError('Failed to load participation history: $e');
      _memberParticipationHistory.clear();
    } finally {
      _loadingMemberHistory = false;
      _safeNotifyListeners();
    }
  }

  Future<void> fetchMemberContributionHistory(String memberId) async {
    _loadingMemberHistory = true;
    _safeNotifyListeners();

    try {
      _memberContributionHistory = await _contributionService.getMemberContributionHistory(memberId);
    } catch (e) {
      _setError('Failed to load contribution history: $e');
      _memberContributionHistory.clear();
    } finally {
      _loadingMemberHistory = false;
      _safeNotifyListeners();
    }
  }

  void clearMemberHistoryData() {
    _memberParticipationHistory.clear();
    _memberContributionHistory.clear();
    _loadingMemberHistory = false;
    _safeNotifyListeners();
  }

  // ==================== ADMIN ACTIONS ====================

  Future<bool> updateMemberRole(String uid, bool makeAdmin) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can update user roles');
      return false;
    }

    // 1. Optimistic Update
    final index = _members.indexWhere((member) => member.uid == uid);
    UserModel? originalMember;
    if (index != -1) {
      originalMember = _members[index];
      _members[index] = _members[index].copyWith(
        isAdmin: makeAdmin,
        role: makeAdmin ? 'admin' : 'member',
      );
      _safeNotifyListeners();
    }

    try {
      await _userService.updateUserRole(uid, makeAdmin);
      return true;
    } catch (e) {
      // 2. Revert on failure
      if (index != -1 && originalMember != null) {
        _members[index] = originalMember;
        _safeNotifyListeners();
      }
      _setError('Failed to update user role: $e');
      return false;
    }
  }

  Future<bool> unapproveUser(String uid) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can unapprove users');
      return false;
    }

    // 1. Optimistic Update
    final index = _members.indexWhere((member) => member.uid == uid);
    UserModel? removedMember;
    if (index != -1) {
      removedMember = _members.removeAt(index);
      _safeNotifyListeners();
    }

    try {
      await _userService.unapproveUser(uid);
      return true;
    } catch (e) {
      // 2. Revert on failure
      if (removedMember != null) {
        _members.insert(index, removedMember);
        _safeNotifyListeners();
      }
      _setError('Failed to unapprove user: $e');
      return false;
    }
  }

  Future<bool> removeFromCommunity(String uid) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can remove users from community');
      return false;
    }

    final communityId = currentUser.communityId;
    if (communityId == null || communityId.isEmpty) {
      _setError('No community found');
      return false;
    }

    // 1. Optimistic Update
    final index = _members.indexWhere((member) => member.uid == uid);
    UserModel? removedMember;
    if (index != -1) {
      removedMember = _members.removeAt(index);
      _safeNotifyListeners();
    }

    try {
      await _userService.removeFromCommunity(uid, communityId);
      return true;
    } catch (e) {
      // 2. Revert on failure
      if (removedMember != null) {
        _members.insert(index, removedMember);
        _safeNotifyListeners();
      }
      _setError('Failed to remove user from community: $e');
      return false;
    }
  }

  Future<bool> bulkUpdateMemberRoles(List<String> uids, bool makeAdmin) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can update user roles');
      return false;
    }

    // 1. Optimistic Update
    final Map<int, UserModel> originalMembers = {};
    for (final uid in uids) {
      final index = _members.indexWhere((m) => m.uid == uid);
      if (index != -1) {
        originalMembers[index] = _members[index];
        _members[index] = _members[index].copyWith(
          isAdmin: makeAdmin,
          role: makeAdmin ? 'admin' : 'member',
        );
      }
    }
    _safeNotifyListeners();

    try {
      for (final uid in uids) {
        await _userService.updateUserRole(uid, makeAdmin);
      }
      return true;
    } catch (e) {
      // 2. Revert on failure
      originalMembers.forEach((index, member) {
        _members[index] = member;
      });
      _safeNotifyListeners();
      _setError('Failed to update user roles: $e');
      return false;
    }
  }

  Future<bool> bulkUnapproveUsers(List<String> uids) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can unapprove users');
      return false;
    }

    // 1. Optimistic Update
    final List<UserModel> removedMembers = [];
    final List<int> originalIndices = [];
    
    // We sort uids in reverse order of their appearance in _members to make deletion/insertion easier?
    // Actually, just capturing them is enough if we use a safe way to revert.
    for (final uid in uids) {
      final index = _members.indexWhere((m) => m.uid == uid);
      if (index != -1) {
        originalIndices.add(index);
        removedMembers.add(_members[index]);
      }
    }
    
    _members.removeWhere((member) => uids.contains(member.uid));
    _safeNotifyListeners();

    try {
      for (final uid in uids) {
        await _userService.unapproveUser(uid);
      }
      return true;
    } catch (e) {
      // 2. Revert on failure
      for (int i = 0; i < removedMembers.length; i++) {
        _members.insert(originalIndices[i], removedMembers[i]);
      }
      _safeNotifyListeners();
      _setError('Failed to unapprove users: $e');
      return false;
    }
  }

  Future<bool> bulkRemoveFromCommunity(List<String> uids) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can remove users from community');
      return false;
    }

    final communityId = currentUser.communityId;
    if (communityId == null || communityId.isEmpty) {
      _setError('No community found');
      return false;
    }

    // 1. Optimistic Update
    final List<UserModel> removedMembers = [];
    final List<int> originalIndices = [];
    
    for (final uid in uids) {
      final index = _members.indexWhere((m) => m.uid == uid);
      if (index != -1) {
        originalIndices.add(index);
        removedMembers.add(_members[index]);
      }
    }
    
    _members.removeWhere((member) => uids.contains(member.uid));
    _safeNotifyListeners();

    try {
      for (final uid in uids) {
        await _userService.removeFromCommunity(uid, communityId);
      }
      return true;
    } catch (e) {
      // 2. Revert on failure
      for (int i = 0; i < removedMembers.length; i++) {
        _members.insert(originalIndices[i], removedMembers[i]);
      }
      _safeNotifyListeners();
      _setError('Failed to remove users from community: $e');
      return false;
    }
  }
 Future<bool> bulkDeleteVirtualUsers(List<String> userIds) async {
    try {
      final currentUser = _authProvider.user;
      if (currentUser == null || !currentUser.isAdmin) {
        throw Exception('Only admins can delete virtual users');
      }

      // Delete each virtual user
      for (final userId in userIds) {
        await _virtualUserService.deleteVirtualUser(userId);
      }

      // Refresh the members list
      await loadMembers(reset: true);
      
      return true;
    } catch (e) {
      debugPrint('❌ DEBUG: Error deleting virtual users: $e');
      _error = 'Failed to delete virtual users: $e';
      notifyListeners();
      return false;
    }
  }

  // ==================== UTILITY METHODS ====================

  List<UserModel> searchMembers(String query) {
    if (query.isEmpty) return _members;
    
    final searchTerm = query.toLowerCase();
    return _members.where((member) {
      final name = member.displayName?.toLowerCase() ?? '';
      final email = member.email.toLowerCase();
      final phone = member.phoneNumber?.toLowerCase() ?? '';
      
      return name.contains(searchTerm) || 
             email.contains(searchTerm) || 
             phone.contains(searchTerm);
    }).toList();
  }

  Map<String, dynamic> getMemberStatistics(String memberId) {
    final participations = _memberParticipationHistory.length;
    final contributions = _memberContributionHistory.length;
    
    final totalContributed = _memberContributionHistory.fold(
      0.0, 
      (sum, c) => sum + (c['amount'] ?? 0.0)
    );
    
    final paidParticipations = _memberParticipationHistory
        .where((p) => p['hasPaidContribution'] == true)
        .length;

    return {
      'totalParticipations': participations,
      'totalContributions': contributions,
      'totalAmountContributed': totalContributed,
      'paidParticipations': paidParticipations,
      'participationRate': participations > 0 ? (paidParticipations / participations) * 100 : 0,
      'averageContribution': contributions > 0 ? totalContributed / contributions : 0,
    };
  }

  void refreshMembers() {
    loadMembers(reset: true);
  }

  void clearError() {
    _error = null;
    _safeNotifyListeners();
  }

  // ==================== PRIVATE HELPERS ====================

  void _setLoading(bool value) {
    _isLoading = value;
    _safeNotifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _isLoading = false;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    Future.microtask(() {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool _disposed = false;

  /// Clear all data (for logout)
  void clearAllData() {
    _members = [];
    _selectedMember = null;
    _memberParticipationHistory = [];
    _memberContributionHistory = [];
    _isLoading = false;
    _loadingMemberHistory = false;
    _error = null;
    _currentFilter = 'all';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

