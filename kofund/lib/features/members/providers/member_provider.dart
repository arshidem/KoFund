// lib/features/members/providers/member_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Pagination state
  final int _pageSize = 15;
  DocumentSnapshot? _lastDocument;
  String _currentFilter = 'all';
  bool _hasMoreData = true;
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  
  // Data
  List<UserModel> _members = [];
  UserModel? _selectedMember;
  
  // Member history
  List<Map<String, dynamic>> _memberParticipationHistory = [];
  List<Map<String, dynamic>> _memberContributionHistory = [];
  bool _loadingMemberHistory = false;

  // Add pagination lock
  bool _isLoadingPage = false;

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

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  List<UserModel> get members => _members;
  UserModel? get selectedMember => _selectedMember;
  bool get hasMoreData => _hasMoreData;
  
  // Member history getters
  List<Map<String, dynamic>> get memberParticipationHistory => _memberParticipationHistory;
  List<Map<String, dynamic>> get memberContributionHistory => _memberContributionHistory;
  bool get loadingMemberHistory => _loadingMemberHistory;

  // ==================== PAGINATION METHODS ====================
/// Load first page of members with server-side filtering
Future<void> loadMembers({String filterType = 'all', bool reset = true}) async {
  // Prevent concurrent loads
  if (_isLoadingPage) {
    developer.log('⏸️ MemberProvider: loadMembers skipped - already loading');
    return;
  }
  
  final user = _authProvider.user;
  if (user == null || user.communityId == null) {
    developer.log('⚠️ MemberProvider: No user or community ID');
    _members = [];
    _safeNotifyListeners();
    return;
  }
  
  developer.log('🔄 MemberProvider: loadMembers called - filter: $filterType, reset: $reset');
  developer.log('📊 Current state: _currentFilter: $_currentFilter, _hasMoreData: $_hasMoreData, _lastDocument: ${_lastDocument != null}');
  
  // Reset pagination for new filter or reset request
  if (reset || filterType != _currentFilter) {
    developer.log('🔄 Resetting pagination - new filter: $filterType, old filter: $_currentFilter');
    _resetPagination();
    _currentFilter = filterType;
  }
  
  _isLoading = true;
  _isLoadingPage = true;
  _error = null;
  _safeNotifyListeners();
  
  try {
    developer.log('🔍 MemberProvider: Fetching users for community: ${user.communityId}, filter: $filterType');
    
    final users = await _userService.getUsersByCommunity(
      user.communityId!,
      filterType: filterType,
      limit: _pageSize,
      lastDocument: null,
      loadMore: false,
    );
    
    developer.log('📥 MemberProvider: Received ${users.length} users');
    
    // Update pagination state
    if (users.isNotEmpty) {
      developer.log('📄 MemberProvider: Getting last document snapshot...');
      _lastDocument = await _getLastDocumentSnapshot(users.last, user.communityId!, filterType);
      developer.log('✅ MemberProvider: Got last document: ${_lastDocument != null}');
    }
    
    _hasMoreData = users.length == _pageSize;
    developer.log('📊 MemberProvider: _hasMoreData set to $_hasMoreData (pageSize: $_pageSize, users: ${users.length})');
    
    _members = users;
    
    // Sort alphabetically
    _members.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
    
    developer.log('✅ MemberProvider: Loaded ${_members.length} members (filter: $filterType)');
    
    // Debug: List all loaded members
    for (var member in _members) {
      developer.log('👤 Member: ${member.displayName} | isVirtualUser: ${member.isVirtualUser} | uid: ${member.uid}');
    }
    
  } catch (e, stackTrace) {
    _error = 'Failed to load members: $e';
    developer.log('❌ MemberProvider Error: $e', error: e, stackTrace: stackTrace);
    _members = [];
  } finally {
    _isLoading = false;
    _isLoadingPage = false;
    _safeNotifyListeners();
  }
}

/// Load next page of members
Future<void> loadMoreMembers({String filterType = 'all'}) async {
  developer.log('🔄 MemberProvider: loadMoreMembers called - filter: $filterType');
  developer.log('📊 Current state: _isLoadingMore: $_isLoadingMore, _hasMoreData: $_hasMoreData, _lastDocument: ${_lastDocument != null}, _isLoadingPage: $_isLoadingPage');
  developer.log('📊 Current filter: $_currentFilter, requested filter: $filterType');
  
  if (_isLoadingMore) {
    developer.log('⏸️ MemberProvider: loadMoreMembers skipped - already loading more');
    return;
  }
  
  if (!_hasMoreData) {
    developer.log('⏸️ MemberProvider: loadMoreMembers skipped - no more data');
    return;
  }
  
  if (_lastDocument == null) {
    developer.log('⏸️ MemberProvider: loadMoreMembers skipped - no last document');
    return;
  }
  
  if (_isLoadingPage) {
    developer.log('⏸️ MemberProvider: loadMoreMembers skipped - page loading');
    return;
  }
  
  // ⚠️ IMPORTANT: Check if filter changed
  if (filterType != _currentFilter) {
    developer.log('⚠️ MemberProvider: Filter mismatch! Current: $_currentFilter, Requested: $filterType');
    developer.log('🔄 MemberProvider: Calling loadMembers with new filter instead');
    await loadMembers(filterType: filterType, reset: true);
    return;
  }
  
  final user = _authProvider.user;
  if (user == null || user.communityId == null) {
    developer.log('⚠️ MemberProvider: No user or community ID for loadMore');
    return;
  }
  
  _isLoadingMore = true;
  _isLoadingPage = true;
  _safeNotifyListeners();
  
  try {
    developer.log('🔍 MemberProvider: Fetching more users for community: ${user.communityId}, filter: $filterType');
    developer.log('📄 Using last document: ${_lastDocument!.id}');
    
    final users = await _userService.getUsersByCommunity(
      user.communityId!,
      filterType: filterType,
      limit: _pageSize,
      lastDocument: _lastDocument,
      loadMore: true,
    );
    
    developer.log('📥 MemberProvider: Received ${users.length} more users');
    
    if (users.isNotEmpty) {
      // Update pagination cursor
      developer.log('📄 MemberProvider: Getting new last document snapshot...');
      _lastDocument = await _getLastDocumentSnapshot(users.last, user.communityId!, filterType);
      developer.log('✅ MemberProvider: New last document: ${_lastDocument != null}');
      
      _hasMoreData = users.length == _pageSize;
      developer.log('📊 MemberProvider: _hasMoreData set to $_hasMoreData (pageSize: $_pageSize, users: ${users.length})');
      
      // Add to existing members
      _members.addAll(users);
      
      // Re-sort
      _members.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
      
      developer.log('✅ MemberProvider: Loaded ${users.length} more members (total: ${_members.length})');
      
      // Debug: List newly loaded members
      for (var member in users) {
        developer.log('👤+ More Member: ${member.displayName} | isVirtualUser: ${member.isVirtualUser}');
      }
    } else {
      _hasMoreData = false;
      developer.log('📊 MemberProvider: No more users, _hasMoreData set to false');
    }
    
  } catch (e, stackTrace) {
    _error = 'Failed to load more members: $e';
    developer.log('❌ MemberProvider Error loading more: $e', error: e, stackTrace: stackTrace);
  } finally {
    _isLoadingMore = false;
    _isLoadingPage = false;
    _safeNotifyListeners();
  }
}

/// Get last document snapshot for pagination
Future<DocumentSnapshot?> _getLastDocumentSnapshot(
  UserModel lastUser, 
  String communityId, 
  String filterType
) async {
  try {
    developer.log('🔍 _getLastDocumentSnapshot: Getting snapshot for user ${lastUser.uid}, filter: $filterType');
    
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('uid', isEqualTo: lastUser.uid)
        .limit(1);
    
    if (filterType == 'real') {
      query = query.where('isVirtualUser', isEqualTo: false);
      developer.log('🎯 Adding isVirtualUser = false filter');
    } else if (filterType == 'virtual') {
      query = query.where('isVirtualUser', isEqualTo: true);
      developer.log('🎯 Adding isVirtualUser = true filter');
    }
    
    final snapshot = await query.get();
    developer.log('📄 _getLastDocumentSnapshot: Query returned ${snapshot.docs.length} documents');
    
    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  } catch (e, stackTrace) {
    developer.log('❌ Error getting last document: $e', error: e, stackTrace: stackTrace);
    return null;
  }
}

/// Reset pagination state
void resetPagination() {
  developer.log('🔄 MemberProvider: Pagination reset');
  _lastDocument = null;
  _hasMoreData = true;
  _currentFilter = 'all';
  _isLoadingPage = false;
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
    _isLoadingMore = false;
    _isLoadingPage = false;
    resetPagination();
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
    _isLoadingMore = false;
    _isLoadingPage = false;
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
        _safeNotifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to update user role: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> unapproveUser(String uid) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can unapprove users');
      return false;
    }

    _setLoading(true);
    try {
      await _userService.unapproveUser(uid);
      
      // Remove from local list
      _members.removeWhere((member) => member.uid == uid);
      _safeNotifyListeners();
      
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
      final communityId = currentUser.communityId;
      if (communityId == null || communityId.isEmpty) {
        _setError('No community found');
        return false;
      }

      await _userService.removeFromCommunity(uid, communityId);
      
      // Remove from local list
      _members.removeWhere((member) => member.uid == uid);
      _safeNotifyListeners();
      
      return true;
    } catch (e) {
      _setError('Failed to remove user from community: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> bulkUpdateMemberRoles(List<String> uids, bool makeAdmin) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can update user roles');
      return false;
    }

    _setLoading(true);
    try {
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
      
      _safeNotifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update user roles: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> bulkUnapproveUsers(List<String> uids) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can unapprove users');
      return false;
    }

    _setLoading(true);
    try {
      for (final uid in uids) {
        await _userService.unapproveUser(uid);
      }
      
      _members.removeWhere((member) => uids.contains(member.uid));
      _safeNotifyListeners();
      
      return true;
    } catch (e) {
      _setError('Failed to unapprove users: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> bulkRemoveFromCommunity(List<String> uids) async {
    final currentUser = _authProvider.user;
    if (currentUser == null || !currentUser.isAdmin) {
      _setError('Only admins can remove users from community');
      return false;
    }

    _setLoading(true);
    try {
      final communityId = currentUser.communityId;
      if (communityId == null || communityId.isEmpty) {
        _setError('No community found');
        return false;
      }

      for (final uid in uids) {
        await _userService.removeFromCommunity(uid, communityId);
      }
      
      _members.removeWhere((member) => uids.contains(member.uid));
      _safeNotifyListeners();
      
      return true;
    } catch (e) {
      _setError('Failed to remove users from community: $e');
      return false;
    } finally {
      _setLoading(false);
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
      print('❌ DEBUG: Error deleting virtual users: $e');
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
      final email = member.email?.toLowerCase() ?? '';
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

  void _resetPagination() {
    _lastDocument = null;
    _hasMoreData = true;
    _isLoadingPage = false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (!value) _isLoadingPage = false;
    _safeNotifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _isLoading = false;
    _isLoadingMore = false;
    _isLoadingPage = false;
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}