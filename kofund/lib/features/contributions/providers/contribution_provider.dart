// lib/features/contributions/providers/contribution_provider.dart
import 'package:flutter/material.dart';
import '../../../core/services/contribution_service.dart';
import '../../../core/services/deleted_contribution_service.dart';
import '../models/contribution_model.dart';
import '../models/deleted_contribution_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

  // Cache entry class
  class CacheEntry {
    final List<ContributionModel> data;
    final DateTime timestamp;
    
    CacheEntry({required this.data, required this.timestamp});
  }

class ContributionProvider with ChangeNotifier {
  final ContributionService _contributionService = ContributionService();
  final DeletedContributionService _deletedContributionService = DeletedContributionService();
 final Map<String, CacheEntry> _cache = {}; // Simplified cache structure
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Add this
  List<ContributionModel> _contributions = [];
  List<ContributionModel> _userContributions = [];
  List<ContributionModel> _communityContributions = [];
  bool _isLoading = false;
  String? _error;
  double _totalContributions = 0;
  Map<String, dynamic> _paymentStats = {};
  List<Map<String, dynamic>> _topContributors = [];
  List<ContributionModel> get contributions => _contributions;
  List<ContributionModel> get userContributions => _userContributions;
  List<ContributionModel> get communityContributions => _communityContributions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get totalContributions => _totalContributions;
  Map<String, dynamic> get paymentStats => _paymentStats;
  List<Map<String, dynamic>> get topContributors => _topContributors;

  // ✅ ADDED: Refresh method for compatibility
  Future<void> refresh() async {
    debugPrint('🔄 ContributionProvider: Refreshing...');
    notifyListeners();
  }

  // -------------------------------
  // 🔹 CRUD Operations
  // -------------------------------

  // Add contribution
  Future<void> addContribution(ContributionModel contribution) async {
    try {
      await _contributionService.addContribution(contribution);
      
      // Clear relevant cache
      clearCacheForUser(contribution.contributionId, contribution.userId);
      
      // Reload contributions after adding new one
      if (contribution.contributionId.isNotEmpty) {
        await loadContributions(contribution.eventId);
      }
      await loadUserContributions(contribution.userId, contribution.communityId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
// In your provider
Future<void> updateContribution(
  ContributionModel contribution, {
  required String editedByUserId,
  required String editedByUserName,
  String? editReason,
}) async {
  try {
    // DEBUG
    debugPrint('📱 Provider: Updating contribution ${contribution.contributionId}');
    
    // First, update in Firestore
    await _contributionService.updateContribution(
      contribution,
      editedByUserId: editedByUserId,
      editedByUserName: editedByUserName,
      editReason: editReason,
    );
    
    // Now update locally (only if Firestore update succeeded)
    final index = contributions.indexWhere(
      (c) => c.contributionId == contribution.contributionId
    );
    
    if (index != -1) {
      // Get current version for comparison
      final currentContribution = contributions[index];
      
      // Detect changes locally
      final Map<String, Map<String, dynamic>> changes = {};
      
      // Helper function to get event title
      Future<String?> getEventTitle(String eventId) async {
        try {
          // Try to get from local cache first if you have a event provider
          // Or fetch from Firestore
          final doc = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .get();
          
          if (doc.exists) {
            return doc.data()?['title'] as String? ?? 'event $eventId';
          }
          
          // Try communities subcollection
          final communityId = currentContribution.communityId;
          final suDoc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('events')
              .doc(eventId)
              .get();
              
          if (suDoc.exists) {
            return suDoc.data()?['title'] as String? ?? 'event $eventId';
          }
          
          return 'event $eventId';
        } catch (e) {
          debugPrint('⚠️ Error fetching event title: $e');
          return 'event $eventId';
        }
      }
      
      // Compare amount
      if (currentContribution.amount != contribution.amount) {
        changes['amount'] = {
          'old': currentContribution.amount,
          'new': contribution.amount,
        };
      }
      
      // Compare payment method
      if (currentContribution.paymentMethod != contribution.paymentMethod) {
        changes['paymentMethod'] = {
          'old': currentContribution.paymentMethod,
          'new': contribution.paymentMethod,
        };
      }
      
      // Compare userId (if this can be changed)
      if (currentContribution.userId != contribution.userId) {
        changes['userId'] = {
          'old': currentContribution.userId,
          'new': contribution.userId,
        };
      }
      
      // Compare eventId - STORE TITLES NOT IDS
      if (currentContribution.contributionId != contribution.contributionId) {
        // Fetch both event titles
        final oldTitle = await getEventTitle(currentContribution.eventId);
        final newTitle = await getEventTitle(contribution.contributionId);
        
        changes['event'] = { // Changed from 'eventId' to 'event' for clarity
          'old': oldTitle,
          'new': newTitle,
          // Store IDs as well for reference if needed
          'oldId': currentContribution.contributionId,
          'newId': contribution.contributionId,
        };
      } else {
        // Even if not changed, we might want to include event title for context
        // Optional: Include event title in changes for reference
        // final title = await _geTtitle(contribution.contributionId);
        // changes['nfo'] = {
        //   'title': title,
        //   'id': contribution.contributionId,
        // };
      }
      
 
      
      // Compare monthId
      if (currentContribution.monthId != contribution.monthId) {
        changes['monthId'] = {
          'old': currentContribution.monthId ?? '',
          'new': contribution.monthId ?? '',
        };
      }
      
      // Compare isMonthlyContribution
      if (currentContribution.isMonthlyContribution != contribution.isMonthlyContribution) {
        changes['isMonthlyContribution'] = {
          'old': currentContribution.isMonthlyContribution,
          'new': contribution.isMonthlyContribution,
        };
      }

      final editRecord = {
        'editedAt': Timestamp.now(),
        'editedByUserId': editedByUserId,
        'editedByUserName': editedByUserName,
        'changes': changes,
        'reason': editReason ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Update local model
      final updatedContribution = contribution.copyWith(
        isEdited: true,
        lastEditedByUserId: editedByUserId,
        lastEditedByUserName: editedByUserName,
        lastEditedAt: Timestamp.now(),
        editReason: editReason,
        editHistory: [...currentContribution.editHistory, editRecord],
      );
      
      // Update in local list
      contributions[index] = updatedContribution;
      
      // Also update in other lists if they exist
      _updateContributionInLists(updatedContribution);
      
      // Clear cache
      clearCacheForUser(contribution.contributionId, contribution.userId);
      
      notifyListeners();
      debugPrint('✅ Provider: Local update successful');
    } else {
      debugPrint('⚠️ Warning: Contribution not found in local list, but Firestore update succeeded');
    }
    
  } catch (e) {
    debugPrint('❌ Provider error: $e');
    rethrow;
  }
}

  void _updateContributionInLists(ContributionModel updatedContribution) {
    // Update in community contributions
    final communityIndex = _communityContributions.indexWhere(
      (c) => c.contributionId == updatedContribution.contributionId
    );
    if (communityIndex >= 0) {
      _communityContributions[communityIndex] = updatedContribution;
    }

    // Update in user contributions
    final userIndex = _userContributions.indexWhere(
      (c) => c.contributionId == updatedContribution.contributionId
    );
    if (userIndex >= 0) {
      _userContributions[userIndex] = updatedContribution;
    }

    // Update in event contributions
    final ndex = _contributions.indexWhere(
      (c) => c.contributionId == updatedContribution.contributionId
    );
    if (ndex >= 0) {
      _contributions[ndex] = updatedContribution;
    }
  }

Future<void> deleteContribution(String contributionId, String reason) async {
  try {
    _isLoading = true;
    notifyListeners();
    
    debugPrint('🔄 Starting secure deletion for: $contributionId');
    
    // 1. Get current user (admin)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    
    // 2. Get contribution details
    final contribution = await getContributionById(contributionId);
    if (contribution == null) {
      throw Exception('Contribution not found');
    }
    
    debugPrint('📋 Found contribution: ${contribution.contributionId} for user: ${contribution.userId}');
    
    // 3. Get admin user info (you might need to fetch from users collection)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    final adminName = userDoc.data()?['displayName'] ?? 'Admin';
    
    // 4. Move to deleted_contributions collection
    await _deletedContributionService.moveToDeletedContributions(
      contribution: contribution,
      adminId: currentUser.uid,
      adminName: adminName,
      reason: reason,
    );
    
    // 5. Clear relevant cache
    clearCacheForUser(contribution.contributionId, contribution.userId);
    
    // 6. Remove from local lists
    _removeContributionFromLists(contributionId);
    
    debugPrint('✅ Contribution securely deleted and archived');
    
  } catch (e) {
    debugPrint('❌ Error in deleteContribution: $e');
    rethrow;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

// 🔹 NEW: Helper method to remove from local lists
void _removeContributionFromLists(String contributionId) {
  _contributions.removeWhere((c) => c.contributionId == contributionId);
  _userContributions.removeWhere((c) => c.contributionId == contributionId);
  _communityContributions.removeWhere((c) => c.contributionId == contributionId);
}

// 🔹 NEW: Get deleted contributions for current user
Stream<List<DeletedContributionModel>> getMyDeletedContributions(String communityId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) {
    return Stream.value([]);
  }
  
  return _deletedContributionService.getUserDeletedContributions(
    userId: currentUserId,
    communityId: communityId,
  );
}

// 🔹 NEW: Get all deleted contributions (admin only)
Stream<List<DeletedContributionModel>> getAllDeletedContributions(String communityId) {
  return _deletedContributionService.getAllDeletedContributions(
    communityId: communityId,
  );
}

// 🔹 NEW: Restore a deleted contribution
Future<void> restoreDeletedContribution({
  required String deletedRecordId,
  required String adminName,
}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    
    await _deletedContributionService.restoreDeletedContribution(
      deletedRecordId: deletedRecordId,
      adminId: currentUser.uid,
      adminName: adminName,
    );
    
    notifyListeners();
    
  } catch (e) {
    debugPrint('❌ Error restoring contribution: $e');
    rethrow;
  }
}

// 🔹 NEW: Check if user has deleted contributions
Future<bool> hasDeletedContributions(String communityId) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return false;
  
  return await _deletedContributionService.hasDeletedContributions(
    userId: currentUserId,
    communityId: communityId,
  );
}

  // ✅ REMOVED: bulkMarkPayments (not needed - all contributions are completed)

  // Get event total contributions
  Future<double> getTotalContributions(String eventId) async {
    try {
      return await _contributionService.getTotalContributions(eventId);
    } catch (e) {
      debugPrint('Error getting event total contributions: $e');
      return 0.0;
    }
  }

  // Get event contributions
  Future<List<ContributionModel>> getContributions(String eventId) async {
    try {
      return await _contributionService.getContributions(eventId);
    } catch (e) {
      debugPrint('Error getting event contributions: $e');
      return [];
    }
  }

  // -------------------------------
  // 🔹 Data Loading Methods
  // -------------------------------

  // Load contributions for a event
  Future<void> loadContributions(String eventId, {bool forceRefresh = false}) async {
    final cacheKey = 'event_$eventId';
    final now = DateTime.now();

    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && 
        _cache.containsKey(cacheKey) && 
        now.difference(_cache[cacheKey]!.timestamp) < const Duration(minutes: 5)) {
      _contributions = _cache[cacheKey]!.data;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _contributions = await _contributionService.getContributions(eventId);
      _totalContributions = await _contributionService.getTotalContributions(eventId);
      
      // Update cache
      _cache[cacheKey] = CacheEntry(data: _contributions, timestamp: now);
    } catch (e) {
      debugPrint('Error loading event contributions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user's contributions for a event
  Future<void> loadUseContributions(String eventId, String userId) async {
    try {
      _userContributions = await _contributionService.getUseContributions(eventId, userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user event contributions: $e');
    }
  }

  // Load user's all contributions in community
  Future<void> loadUserContributions(String userId, String communityId, {bool forceRefresh = false}) async {
    final cacheKey = 'user_${userId}_$communityId';
    final now = DateTime.now();

    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && 
        _cache.containsKey(cacheKey) && 
        now.difference(_cache[cacheKey]!.timestamp) < const Duration(minutes: 5)) {
      _userContributions = _cache[cacheKey]!.data;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _userContributions = await _contributionService.getUserContributions(userId, communityId);
      
      // Update cache
      _cache[cacheKey] = CacheEntry(data: _userContributions, timestamp: now);
    } catch (e) {
      debugPrint('Error loading user contributions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load all contributions in community (for admin)
  Future<void> loadCommunityContributions(String communityId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _communityContributions = await _contributionService.getCommunityContributions(communityId);
      debugPrint('✅ Loaded ${_communityContributions.length} community contributions');
    } catch (e) {
      debugPrint('❌ Error loading community contributions: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load payment statistics for community
  Future<void> loadPaymentStats(String communityId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _paymentStats = await _contributionService.getCommunityPaymentStats(communityId);
    } catch (e) {
      debugPrint('Error loading payment stats: $e');
      _paymentStats = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load top contributors for community
  Future<void> loadTopContributors(String communityId, {int limit = 10}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _topContributors = await _contributionService.getTopContributors(communityId, limit: limit);
    } catch (e) {
      debugPrint('Error loading top contributors: $e');
      _topContributors = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -------------------------------
  // 🔹 Calculation & Analytics Methods
  // -------------------------------

  // Get user's total contributions for a event
  Future<double> getUseTotal(String eventId, String userId) async {
    try {
      return await _contributionService.getUseTotalContributions(eventId, userId);
    } catch (e) {
      debugPrint('Error getting user event total: $e');
      return 0;
    }
  }

  // Get user's total contributions in community
  Future<double> getUserTotalContributions(String userId, String communityId) async {
    try {
      return await _contributionService.getUserTotalContributions(userId, communityId);
    } catch (e) {
      debugPrint('Error getting user total contributions: $e');
      return 0;
    }
  }

  // Get user's payment progress for a event
  Future<Map<String, dynamic>> getUserPaymentProgress(String eventId, String userId) async {
    try {
      return await _contributionService.getUserPaymentProgress(eventId, userId);
    } catch (e) {
      debugPrint('Error getting payment progress: $e');
      return {
        'totalPaid': 0,
        'suggestedAmount': 0,
        'remainingAmount': 0,
        'progressPercentage': 0,
        'isFullyPaid': false,
        'isOverpaid': false,
      };
    }
  }

  // Get event payment summary with participant breakdown
  Future<Map<String, dynamic>> getPaymentSummary(String eventId) async {
    try {
      return await _contributionService.getPaymentSummary(eventId);
    } catch (e) {
      debugPrint('Error getting event payment summary: $e');
      return {};
    }
  }

  // Get user's payment history with event details
  Future<List<Map<String, dynamic>>> getUserPaymentHistoryWithDetails(
      String userId, String communityId) async {
    try {
      return await _contributionService.getUserPaymentHistoryWithDetails(userId, communityId);
    } catch (e) {
      debugPrint('Error getting user payment history: $e');
      return [];
    }
  }

  // -------------------------------
  // 🔹 Filtering & Query Methods (SIMPLIFIED)
  // -------------------------------

 // Get contribution by ID
// In your ContributionProvider class
Future<ContributionModel?> getContributionById(String contributionId) async {
  try {
    debugPrint('🔄 Getting contribution by ID: $contributionId');
    
    // Try with the given ID first
    var docRef = FirebaseFirestore.instance
        .collection('contributions')
        .doc(contributionId);
    
    var snapshot = await docRef.get();
    
    // If not found, try adding 'contrib_' prefix
    if (!snapshot.exists && !contributionId.startsWith('contrib_')) {
      debugPrint('⚠️ Not found, trying with "contrib_" prefix...');
      docRef = FirebaseFirestore.instance
          .collection('contributions')
          .doc('contrib_$contributionId');
      snapshot = await docRef.get();
    }
    
    if (!snapshot.exists) {
      debugPrint('❌ Contribution not found with ID: $contributionId');
      return null; // Return null instead of throwing
    }
    
    final data = snapshot.data();
    if (data == null) {
      debugPrint('❌ Contribution data is invalid or null');
      return null; // Return null instead of throwing
    }
    
    debugPrint('✅ Found contribution: ${snapshot.id}');
    return ContributionModel.fromMap(data, snapshot.id);
    
  } catch (e) {
    debugPrint('❌ Error getting contribution by ID: $e');
    return null; // Return null instead of rethrowing
  }
}

  // ✅ REMOVED: pendingContributions getter (all contributions are completed)

  // ✅ SIMPLIFIED: All contributions are completed
  List<ContributionModel> get completedContributions => _contributions;

  // ✅ SIMPLIFIED: All user contributions are completed
  List<ContributionModel> get userCompletedContributions => _userContributions;

  // Get contributions by payment method
  List<ContributionModel> getContributionsByPaymentMethod(String paymentMethod) {
    return _contributions.where((contribution) => contribution.paymentMethod == paymentMethod).toList();
  }

  // Get contributions by date range
  List<ContributionModel> getContributionsByDateRange(DateTime startDate, DateTime endDate) {
    return _contributions.where((contribution) =>
      contribution.createdAt.toDate().isAfter(startDate) &&
      contribution.createdAt.toDate().isBefore(endDate)
    ).toList();
  }

  // Get total contributions by user in a event
  double getUserTotalI(String eventId, String userId) {
    final userContributions = _contributions.where((contribution) =>
      contribution.eventId == eventId &&
      contribution.userId == userId
    ).toList();
    
    return userContributions.fold(0, (sum, contribution) => sum + contribution.amount);
  }

  // Check if user has contributed to a event
  bool hasUserContributed(String eventId, String userId) {
    return _contributions.any((contribution) =>
      contribution.eventId == eventId &&
      contribution.userId == userId
    );
  }
  Future<List<ContributionModel>> getUserContributionsFo(
    String eventId, 
    String userId,
    {bool forceRefresh = false}
  ) async {
    final cacheKey = '$eventId-$userId';
    final now = DateTime.now();
    
    // Check cache (valid for 30 seconds)
    if (!forceRefresh && 
        _cache.containsKey(cacheKey) && 
        now.difference(_cache[cacheKey]!.timestamp) < Duration(seconds: 30)) {
      debugPrint('📦 Using cached contributions for $cacheKey');
      return _cache[cacheKey]!.data;
    }
    
    try {
      debugPrint('🌐 Fetching freshhh contributions from Firestore for $cacheKey');
      
      final querySnapshot = await _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .limit(50) // Add reasonable limit
          .get(const GetOptions(source: Source.serverAndCache)); // Use cache when possible
      
      final contributions = querySnapshot.docs
          .map((doc) => ContributionModel.fromMap(doc.data(), doc.id))
          .toList();
      
      debugPrint('✅ Fetched ${contributions.length} contributions from Firestore');
      
      // Update cache
      _cache[cacheKey] = CacheEntry(
        data: contributions,
        timestamp: now,
      );
      
      return contributions;
    } catch (e) {
      debugPrint('❌ Error fetching contributions from Firestore: $e');
      
      // Return cached data if available (even if stale)
      if (_cache.containsKey(cacheKey)) {
        debugPrint('⚠️ Returning stale cached data due to error');
        return _cache[cacheKey]!.data;
      }
      
      return [];
    }
  }
  
  // Clear specific cache entry
  void clearCacheForUser(String eventId, String userId) {
    final cacheKey = '$eventId-$userId';
    if (_cache.containsKey(cacheKey)) {
      _cache.remove(cacheKey);
      debugPrint('🗑️ Cleared cache for $cacheKey');
    }
  }

  // Clear all cache
  void clearAllCache() {
    _cache.clear();
    debugPrint('🗑️ Cleared all cache entries');
  }



  // Get users who haven't paid for a event
  List<String> getUsersWithNoContributions(String eventId, List<String> allUserIds) {
    final contributors = _contributions
        .where((contribution) => contribution.eventId == eventId)
        .map((contribution) => contribution.userId)
        .toSet();
    
    return allUserIds.where((userId) => !contributors.contains(userId)).toList();
  }

  // ✅ REMOVED: overdueContributions getter (all contributions are completed)

  // -------------------------------
  // 🔹 Utility Methods
  // -------------------------------

// In lib/features/contributions/providers/contribution_provider.dart
void clearUserData() {
  // Clear any user-specific caches
  _userContributions.clear();
  _isLoading = false;
  _error = null;
  notifyListeners();
  debugPrint('🔄 ContributionProvider: User data cleared');
}

// Add this for compatibility
void clearAllData() {
  clearUserData();
}

  // Refresh all data for a community
  Future<void> refreshCommunityData(String communityId, String userId) async {
    await Future.wait([
      loadCommunityContributions(communityId),
      loadUserContributions(userId, communityId),
      loadPaymentStats(communityId),
      loadTopContributors(communityId),
    ]);
  }

  // Check if user is top contributor
  bool isUserTopContributor(String userId, {int topN = 5}) {
    if (_topContributors.isEmpty) return false;
    
    final topUserIds = _topContributors.take(topN).map((user) => user['userId']).toList();
    return topUserIds.contains(userId);
  }

  // Get user's rank in community
  int getUserRank(String userId) {
    final userIndex = _topContributors.indexWhere((user) => user['userId'] == userId);
    return userIndex >= 0 ? userIndex + 1 : -1;
  }

  // -------------------------------
  // 🔹 Real-time Streams
  // -------------------------------

  Stream<List<ContributionModel>> streamContributions(String eventId) {
    return _contributionService.streamContributions(eventId);
  }

  Stream<List<ContributionModel>> streamUserContributions(String userId, String communityId) {
    return _contributionService.streamUserContributions(userId, communityId);
  }

  Stream<List<ContributionModel>> streamCommunityContributions(String communityId) {
    return _contributionService.streamCommunityContributions(communityId);
  }

  Stream<double> streamTotalContributions(String eventId) {
    return _contributionService.streamTotalContributions(eventId);
  }

  // -------------------------------
  // 🔹 Analytics Getters (SIMPLIFIED)
  // -------------------------------

  // Get total collected amount from loaded contributions
  double get totalCollectedAamount {
    return _contributions.fold(0, (sum, contribution) => sum + contribution.amount);
  }

  // Get average contribution amount
  double get averageContribution {
    return _contributions.isEmpty ? 0 : totalCollectedAamount / _contributions.length;
  }

  // Get most popular payment method
  String get mostPopularPaymentMethod {
    final methodCounts = <String, int>{};
    
    for (final contribution in _contributions) {
      methodCounts[contribution.paymentMethod] = 
          (methodCounts[contribution.paymentMethod] ?? 0) + 1;
    }
    
    if (methodCounts.isEmpty) return 'None';
    
    return methodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // Get monthly contribution trend
  Map<String, double> get monthlyContributionTrend {
    final monthlyTotals = <String, double>{};
    
    for (final contribution in _contributions) {
      final monthKey = '${contribution.createdAt.toDate().year}-${contribution.createdAt.toDate().month}';
      monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0) + contribution.amount;
    }
    
    return monthlyTotals;
  }

  // ✅ ADDED: Get recent contributions (last 30 days)
  List<ContributionModel> get recentContributions {
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
    return _contributions.where((contribution) =>
      contribution.createdAt.toDate().isAfter(thirtyDaysAgo)
    ).toList();
  }

  // ✅ ADDED: Get contributions count by user
  int getContributionsCountByUser(String userId) {
    return _contributions.where((contribution) => contribution.userId == userId).length;
  }

  // ✅ ADDED: Get total amount by user
  double getTotalAamountByUser(String userId) {
    return _contributions
        .where((contribution) => contribution.userId == userId)
        .fold(0, (sum, contribution) => sum + contribution.amount);
  }
// Add this method to ContributionProvider class in contribution_provider.dart

// 🔹 Get monthly contributions for a event-month
Future<List<ContributionModel>> getMonthlyContributionsFo(
  String eventId, 
  String monthId
) async {
  try {
    return await _contributionService.getMonthlyContributionsFo(eventId, monthId);
  } catch (e) {
    debugPrint('❌ Error getting monthly contributions: $e');
    return [];
  }
}

}





