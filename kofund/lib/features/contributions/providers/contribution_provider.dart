// lib/features/contributions/providers/contribution_provider.dart
import 'package:flutter/material.dart';
import '../../../core/services/contribution_service.dart';
import '../models/contribution_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


  // Cache entry class
  class CacheEntry {
    final List<ContributionModel> data;
    final DateTime timestamp;
    
    CacheEntry({required this.data, required this.timestamp});
  }

class ContributionProvider with ChangeNotifier {
  final ContributionService _contributionService = ContributionService();
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

  // -------------------------------
  // 🔹 CRUD Operations
  // -------------------------------

  // Add contribution
  Future<void> addContribution(ContributionModel contribution) async {
    try {
      await _contributionService.addContribution(contribution);
      
      // Clear relevant cache
      clearCacheForUser(contribution.programId, contribution.userId);
      
      // Reload contributions after adding new one
      if (contribution.programId.isNotEmpty) {
        await loadProgramContributions(contribution.programId);
      }
      await loadUserContributions(contribution.userId, contribution.communityId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  // ✅ REMOVED: updateContributionStatus (not needed - all contributions are completed)

  Future<void> updateContribution(ContributionModel contribution) async {
    try {
      await _contributionService.updateContribution(contribution);
      
      // Clear relevant cache
      clearCacheForUser(contribution.programId, contribution.userId);
      
      // Update in local lists
      _updateContributionInLists(contribution);
      notifyListeners();
    } catch (e) {
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

    // Update in program contributions
    final programIndex = _contributions.indexWhere(
      (c) => c.contributionId == updatedContribution.contributionId
    );
    if (programIndex >= 0) {
      _contributions[programIndex] = updatedContribution;
    }
  }

  // Delete contribution
  Future<void> deleteContribution(String contributionId) async {
    try {
      // Get contribution details before deletion to clear correct cache
      final contribution = await getContributionById(contributionId);
      
      await _contributionService.deleteContribution(contributionId);
      
      // Clear relevant cache if we have contribution details
      if (contribution != null) {
        clearCacheForUser(contribution.programId, contribution.userId);
      }
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ REMOVED: bulkMarkPayments (not needed - all contributions are completed)

  // Get program total contributions
  Future<double> getProgramTotalContributions(String programId) async {
    try {
      return await _contributionService.getProgramTotalContributions(programId);
    } catch (e) {
      print('Error getting program total contributions: $e');
      return 0.0;
    }
  }

  // Get program contributions
  Future<List<ContributionModel>> getProgramContributions(String programId) async {
    try {
      return await _contributionService.getProgramContributions(programId);
    } catch (e) {
      print('Error getting program contributions: $e');
      return [];
    }
  }

  // -------------------------------
  // 🔹 Data Loading Methods
  // -------------------------------

  // Load contributions for a program
  Future<void> loadProgramContributions(String programId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _contributions = await _contributionService.getProgramContributions(programId);
      _totalContributions = await _contributionService.getProgramTotalContributions(programId);
    } catch (e) {
      print('Error loading program contributions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user's contributions for a program
  Future<void> loadUserProgramContributions(String programId, String userId) async {
    try {
      _userContributions = await _contributionService.getUserProgramContributions(programId, userId);
      notifyListeners();
    } catch (e) {
      print('Error loading user program contributions: $e');
    }
  }

  // Load user's all contributions in community
  Future<void> loadUserContributions(String userId, String communityId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userContributions = await _contributionService.getUserContributions(userId, communityId);
    } catch (e) {
      print('Error loading user contributions: $e');
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
      print('✅ Loaded ${_communityContributions.length} community contributions');
    } catch (e) {
      print('❌ Error loading community contributions: $e');
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
      print('Error loading payment stats: $e');
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
      print('Error loading top contributors: $e');
      _topContributors = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -------------------------------
  // 🔹 Calculation & Analytics Methods
  // -------------------------------

  // Get user's total contributions for a program
  Future<double> getUserProgramTotal(String programId, String userId) async {
    try {
      return await _contributionService.getUserProgramTotalContributions(programId, userId);
    } catch (e) {
      print('Error getting user program total: $e');
      return 0;
    }
  }

  // Get user's total contributions in community
  Future<double> getUserTotalContributions(String userId, String communityId) async {
    try {
      return await _contributionService.getUserTotalContributions(userId, communityId);
    } catch (e) {
      print('Error getting user total contributions: $e');
      return 0;
    }
  }

  // Get user's payment progress for a program
  Future<Map<String, dynamic>> getUserPaymentProgress(String programId, String userId) async {
    try {
      return await _contributionService.getUserPaymentProgress(programId, userId);
    } catch (e) {
      print('Error getting payment progress: $e');
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

  // Get program payment summary with participant breakdown
  Future<Map<String, dynamic>> getProgramPaymentSummary(String programId) async {
    try {
      return await _contributionService.getProgramPaymentSummary(programId);
    } catch (e) {
      print('Error getting program payment summary: $e');
      return {};
    }
  }

  // Get user's payment history with program details
  Future<List<Map<String, dynamic>>> getUserPaymentHistoryWithDetails(
      String userId, String communityId) async {
    try {
      return await _contributionService.getUserPaymentHistoryWithDetails(userId, communityId);
    } catch (e) {
      print('Error getting user payment history: $e');
      return [];
    }
  }

  // -------------------------------
  // 🔹 Filtering & Query Methods (SIMPLIFIED)
  // -------------------------------

 // Get contribution by ID
  Future<ContributionModel?> getContributionById(String contributionId) async {
    try {
      // First check in cache by searching all loaded contributions
      final allContributions = [..._contributions, ..._userContributions, ..._communityContributions];
      final localResult = allContributions.firstWhere(
        (contribution) => contribution.contributionId == contributionId,
        orElse: () => null as ContributionModel,
      );
      
      if (localResult != null) return localResult;
      
      // If not found locally, try to fetch from Firestore
      final doc = await _firestore.collection('contributions').doc(contributionId).get();
      if (doc.exists) {
        return ContributionModel.fromMap(doc.data()!, doc.id);
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting contribution by ID: $e');
      return null;
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

  // Get total contributions by user in a program
  double getUserTotalInProgram(String programId, String userId) {
    final userContributions = _contributions.where((contribution) =>
      contribution.programId == programId &&
      contribution.userId == userId
    ).toList();
    
    return userContributions.fold(0, (sum, contribution) => sum + contribution.amount);
  }

  // Check if user has contributed to a program
  bool hasUserContributed(String programId, String userId) {
    return _contributions.any((contribution) =>
      contribution.programId == programId &&
      contribution.userId == userId
    );
  }
  Future<List<ContributionModel>> getUserContributionsForProgram(
    String programId, 
    String userId,
    {bool forceRefresh = false}
  ) async {
    final cacheKey = '$programId-$userId';
    final now = DateTime.now();
    
    // Check cache (valid for 30 seconds)
    if (!forceRefresh && 
        _cache.containsKey(cacheKey) && 
        now.difference(_cache[cacheKey]!.timestamp) < Duration(seconds: 30)) {
      print('📦 Using cached contributions for $cacheKey');
      return _cache[cacheKey]!.data;
    }
    
    try {
      print('🌐 Fetching fresh contributions from Firestore for $cacheKey');
      
      final querySnapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .where('userId', isEqualTo: userId)
          .limit(50) // Add reasonable limit
          .get(const GetOptions(source: Source.serverAndCache)); // Use cache when possible
      
      final contributions = querySnapshot.docs
          .map((doc) => ContributionModel.fromMap(doc.data(), doc.id))
          .toList();
      
      print('✅ Fetched ${contributions.length} contributions from Firestore');
      
      // Update cache
      _cache[cacheKey] = CacheEntry(
        data: contributions,
        timestamp: now,
      );
      
      return contributions;
    } catch (e) {
      print('❌ Error fetching contributions from Firestore: $e');
      
      // Return cached data if available (even if stale)
      if (_cache.containsKey(cacheKey)) {
        print('⚠️ Returning stale cached data due to error');
        return _cache[cacheKey]!.data;
      }
      
      return [];
    }
  }
  
  // Clear specific cache entry
  void clearCacheForUser(String programId, String userId) {
    final cacheKey = '$programId-$userId';
    if (_cache.containsKey(cacheKey)) {
      _cache.remove(cacheKey);
      print('🗑️ Cleared cache for $cacheKey');
    }
  }

  // Clear all cache
  void clearAllCache() {
    _cache.clear();
    print('🗑️ Cleared all cache entries');
  }



  // Get users who haven't paid for a program
  List<String> getUsersWithNoContributions(String programId, List<String> allUserIds) {
    final contributors = _contributions
        .where((contribution) => contribution.programId == programId)
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
  print('🔄 ContributionProvider: User data cleared');
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

  Stream<List<ContributionModel>> streamProgramContributions(String programId) {
    return _contributionService.streamProgramContributions(programId);
  }

  Stream<List<ContributionModel>> streamUserContributions(String userId, String communityId) {
    return _contributionService.streamUserContributions(userId, communityId);
  }

  Stream<List<ContributionModel>> streamCommunityContributions(String communityId) {
    return _contributionService.streamCommunityContributions(communityId);
  }

  Stream<double> streamProgramTotalContributions(String programId) {
    return _contributionService.streamProgramTotalContributions(programId);
  }

  // -------------------------------
  // 🔹 Analytics Getters (SIMPLIFIED)
  // -------------------------------

  // Get total collected amount from loaded contributions
  double get totalCollectedAmount {
    return _contributions.fold(0, (sum, contribution) => sum + contribution.amount);
  }

  // Get average contribution amount
  double get averageContribution {
    return _contributions.isEmpty ? 0 : totalCollectedAmount / _contributions.length;
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
  double getTotalAmountByUser(String userId) {
    return _contributions
        .where((contribution) => contribution.userId == userId)
        .fold(0, (sum, contribution) => sum + contribution.amount);
  }
// Add this method to ContributionProvider class in contribution_provider.dart

// 🔹 Get monthly contributions for a program-month
Future<List<ContributionModel>> getMonthlyContributionsForProgram(
  String programId, 
  String monthId
) async {
  try {
    return await _contributionService.getMonthlyContributionsForProgram(programId, monthId);
  } catch (e) {
    print('❌ Error getting monthly contributions: $e');
    return [];
  }
}

}