// lib/features/issues/providers/issue_provider.dart
import 'package:flutter/foundation.dart';
import 'package:kofund/features/issues/models/issue_model.dart';
import 'package:kofund/core/services/issue_service.dart';

class IssueProvider with ChangeNotifier {
  final IssueService _issueService = IssueService();
  
  List<IssueModel> _issues = [];
  List<IssueModel> _myIssues = [];
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'all';
  bool _sortByNewest = true;
  String? _lastCreatedIssueId;
  
  // 🚀 OPTIMIZATION: In-memory cache with TTL
  final Map<String, ({List<IssueModel> data, DateTime timestamp})> _cache = {};
  final Duration _cacheTTL = const Duration(minutes: 5);

  // Getters
  List<IssueModel> get issues => _issues;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedFilter => _selectedFilter;
  bool get sortByNewest => _sortByNewest;
  String? get lastCreatedIssueId => _lastCreatedIssueId;
 List<IssueModel> get myIssues => _myIssues;
  // Statistics
  int get totalIssues => _issues.length;
  int get pendingIssues => _issues.where((i) => i.isPending).length;
  int get inProgressIssues => _issues.where((i) => i.isInProgress).length;
  int get resolvedIssues => _issues.where((i) => i.isResolved).length;
  int get closedIssues => _issues.where((i) => i.isClosed).length;

  Future<void> loadMyIssues(String userId, {bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _cache.containsKey('my_$userId')) {
      final cached = _cache['my_$userId']!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _myIssues = cached.data;
        notifyListeners();
        return;
      }
    }

    _setLoading(true);
    _setError(null);
    
    try {
      _myIssues = await _issueService.getUserIssues(userId);
      _cache['my_$userId'] = (data: _myIssues, timestamp: DateTime.now());
      notifyListeners();
    } catch (e) {
      _setError('Failed to load your issues: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // ✅ ADD THIS: Stream for user's issues
  Stream<List<IssueModel>> getUserIssuesStream(String userId) {
    return _issueService.getUserIssuesStream(userId);
  }
  
  // Update createIssue method to refresh myIssues
  Future<String> createIssue({
    required String title,
    required String description,
    required String type,
    String? stepsToReproduce,
    String? screenshotUrl,
    required String userId, // Add userId parnameter
  }) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final issue = await _issueService.createIssue(
        title: title,
        description: description,
        type: type,
        stepsToReproduce: stepsToReproduce,
        screenshotUrl: screenshotUrl,
        userId: userId,
      );
      
      _lastCreatedIssueId = issue.id;
      
      // Refresh both all issues and user's issues
      await loadIssues();
      await loadMyIssues(userId);
      
      notifyListeners();
      return issue.id;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Load issues from Firestore
  Future<void> loadIssues({bool forceRefresh = false}) async {
    final cacheKey = 'all_${_selectedFilter}_$_sortByNewest';
    
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _issues = cached.data;
        notifyListeners();
        return;
      }
    }

    _setLoading(true);
    _setError(null);
    
    try {
      _issues = await _issueService.getIssues(
        statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
        sortByNewest: _sortByNewest,
      );
      _cache[cacheKey] = (data: _issues, timestamp: DateTime.now());
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Stream issues for real-time updates
  Stream<List<IssueModel>> get issuesStream {
    return _issueService.getIssuesStream(
      statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
      sortByNewest: _sortByNewest,
    );
  }

  // Filter and sort operations
  Future<void> updateFilter(String filter) async {
    _selectedFilter = filter;
    await loadIssues();
  }

  Future<void> toggleSortOrder() async {
    _sortByNewest = !_sortByNewest;
    await loadIssues();
  }

  // Issue management operations
  Future<void> updateIssueStatus(String issueId, String newStatus) async {
    try {
      await _issueService.updateIssueStatus(
        issueId: issueId,
        newStatus: newStatus,
      );
      
      // Update local state
      final index = _issues.indexWhere((issue) => issue.id == issueId);
      if (index != -1) {
        _issues[index] = _issues[index].copyWith(status: newStatus);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> assignIssueToMe({
    required String issueId,
    required String developerId,
    required String developerName,
  }) async {
    try {
      await _issueService.assignIssueToDeveloper(
        issueId: issueId,
        developerId: developerId,
        developerName: developerName,
      );
      
      // Update local state
      final index = _issues.indexWhere((issue) => issue.id == issueId);
      if (index != -1) {
        _issues[index] = _issues[index].copyWith(
          assignedDeveloperId: developerId,
          assignedDeveloperName: developerName,
          status: 'in-progress',
        );
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> addResolutionNotes({
    required String issueId,
    required String notes,
  }) async {
    try {
      await _issueService.addResolutionNotes(
        issueId: issueId,
        notes: notes,
      );
      
      // Update local state
      final index = _issues.indexWhere((issue) => issue.id == issueId);
      if (index != -1) {
        _issues[index] = _issues[index].copyWith(
          resolutionNotes: notes,
        );
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  // Get issue by ID
  Future<IssueModel?> getIssueById(String issueId) async {
    try {
      return await _issueService.getIssueById(issueId);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Clear last created issue ID
  void clearLastCreatedIssue() {
    _lastCreatedIssueId = null;
    notifyListeners();
  }

  // Clear all data
  void clearAllData() {
    _issues.clear();
    _error = null;
    _lastCreatedIssueId = null;
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) notifyListeners();
  }
}





