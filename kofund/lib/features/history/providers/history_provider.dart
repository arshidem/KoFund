// lib/features/history/providers/history_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/services/contribution_service.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/services/program_service.dart';
import '../../../core/services/user_service.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../contributions/models/contribution_model.dart';
import '../../expenses/models/expense_model.dart';
import '../../programs/models/program_model.dart';

// ===== ENUMS =====
enum HistoryItemType { contribution, expense }
enum HistoryFilterType { all, contributions, expenses }

// ===== ITEM MODEL =====
class HistoryItem {
  final String id;
  final HistoryItemType type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final String? userId;
  final String? contributorName;
  final String? programId;
  final String? paymentMethod;
  final String? category;
  final String? rawStatus;
  final dynamic original;

  HistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    this.userId,
    this.contributorName,
    this.programId,
    this.paymentMethod,
    this.category,
    this.rawStatus,
    this.original,
  });

  @override
  String toString() {
    return 'HistoryItem{id: $id, type: $type, title: $title, amount: $amount}';
  }
}

// ==========================================================
//                     PROVIDER CLASS
// ==========================================================

class HistoryProvider with ChangeNotifier {
  final ContributionService _contributionService;
  final ExpenseService _expenseService;
  final ProgramService _programService;
  final UserService _userService;
  final AppAuthProvider _authProvider;
  
  String? _communityId;

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  List<HistoryItem> _items = [];
  
  // Add this missing property
  List<HistoryItem> _filteredItems = []; // ADD THIS LINE

  StreamSubscription<List<ContributionModel>>? _contribSub;
  StreamSubscription<List<ExpenseModel>>? _expenseSub;

  final Map<String, String> _programTitles = {};
  final Map<String, String> _userNames = {};

  // === Filters ===
  HistoryFilterType _filterType = HistoryFilterType.all;
  HistoryFilterType get filterType => _filterType;

  String? _selectedProgramId;
  String? get selectedProgramId => _selectedProgramId;

  DateTime? _startDate;
  DateTime? get startDate => _startDate;

  DateTime? _endDate;
  DateTime? get endDate => _endDate;

  // === Search ===
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Disposed flag for safe notifications
  bool _disposed = false; // ADD THIS LINE

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<HistoryItem> get items => List.unmodifiable(_items);
  List<HistoryItem> get filteredItems => List.unmodifiable(_filteredItems); // ADD THIS GETTER
  String? get communityId => _communityId;

  // Constructor with proper initialization
  HistoryProvider({
    required ContributionService contributionService,
    required ExpenseService expenseService,
    required ProgramService programService,
    required UserService userService,
    required AppAuthProvider authProvider,
  })  : _contributionService = contributionService,
        _expenseService = expenseService,
        _programService = programService,
        _userService = userService,
        _authProvider = authProvider {
    
    // Validate critical dependencies
    _validateDependencies();
    
    // Initialize after a short delay to ensure widget tree is built
    _initializeDelayed();
  }

  void _validateDependencies() {
    if (_contributionService == null) {
      throw ArgumentError('ContributionService cannot be null');
    }
    if (_expenseService == null) {
      throw ArgumentError('ExpenseService cannot be null');
    }
    if (_authProvider == null) {
      throw ArgumentError('AppAuthProvider cannot be null');
    }
  }

  void _initializeDelayed() {
    // Use Future.microtask to ensure initialization happens after build
    Future.microtask(() {
      _initializeFromAuth();
    });
  }

  // ✅ SAFE INITIALIZATION
  void _initializeFromAuth() {
    try {
      print('🔄 HISTORY PROVIDER - Initializing from auth...');
      
      if (_authProvider.user == null) {
        _setError('User not authenticated. Please log in.');
        _isInitialized = true;
        return;
      }

      final user = _authProvider.user!;
      final userCommunityId = user.communityId;
      
      if (userCommunityId == null || userCommunityId.isEmpty) {
        _setError('No community found. Please join a community first.');
        _isInitialized = true;
        return;
      }

      updateCommunityId(userCommunityId);
      _isInitialized = true;
      
      print('✅ HISTORY PROVIDER - Initialized successfully with community: $userCommunityId');
    } catch (e) {
      _setError('Failed to initialize history provider: $e');
      _isInitialized = true;
      print('❌ HISTORY PROVIDER - Initialization error: $e');
    }
  }

  // Method to update communityId from auth provider
  void updateCommunityId(String communityId) {
    if (_communityId != communityId && communityId.isNotEmpty) {
      _communityId = communityId;
      _error = null; // Clear any previous errors
      
      print('🔄 HISTORY PROVIDER - Community ID updated: $communityId');
      
      // Restart streams with new communityId
      _restartStreams();
      
      // Fetch initial data
      fetchOnce();
    }
  }

  // Add this method for safe notification
  void _safeNotifyListeners() { // ADD THIS METHOD
    if (!_disposed) {
      Future.microtask(() {
        if (!_disposed) {
          notifyListeners();
        }
      });
    }
  }

  // Reset method for new user
  void resetForNewUser() { // UPDATED METHOD
    _items = [];
    _filteredItems = []; // Now this property exists
    _error = null;
    _isLoading = false;
    _searchQuery = '';
    _filterType = HistoryFilterType.all;
    _selectedProgramId = null;
    _startDate = null;
    _endDate = null;
    _programTitles.clear();
    _userNames.clear();
    _safeNotifyListeners(); // Now this method exists
    print('🔄 HistoryProvider: Reset for new user - all data cleared');
  }
// In your HistoryProvider class, add these methods:

void clearDataForUserChange() {
  _items = [];
  _filteredItems = [];
  _programTitles.clear();
  _userNames.clear();
  _error = null;
  _isLoading = false;
  _isInitialized = false;
  _searchQuery = '';
  _filterType = HistoryFilterType.all;
  _selectedProgramId = null;
  _startDate = null;
  _endDate = null;
  _communityId = null;
  _safeNotifyListeners();
  print('🔄 HistoryProvider: Data cleared for user change');
}

void setUserCommunity(String communityId) {
  if (_communityId != communityId) {
    clearDataForUserChange();
    _communityId = communityId;
    _isInitialized = true;
    fetchOnce();
    _restartStreams();
    print('✅ HistoryProvider: Set community to $communityId');
  }
}
  // ================= CORE METHODS ==================
  void _setLoading(bool loading) {
    if (_isLoading != loading && !_disposed) {
      _isLoading = loading;
      _safeNotifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error && !_disposed) {
      _error = error;
      _safeNotifyListeners();
    }
  }

  void _restartStreams() {
    _contribSub?.cancel();
    _expenseSub?.cancel();

    if (_communityId == null || _communityId!.isEmpty) {
      _setError('Community ID is not available');
      return;
    }

    try {
      // Start contributions stream
      _contribSub = _contributionService
          .streamCommunityContributions(_communityId!)
          .listen(
            (contributions) => _processContributions(contributions),
            onError: (error) {
              print('❌ Contributions stream error: $error');
              _setError('Failed to load contributions: $error');
            },
          );

      // Start expenses stream
      _expenseSub = _expenseService
          .streamCommunityExpenses(_communityId!)
          .listen(
            (expenses) => _processExpenses(expenses),
            onError: (error) {
              print('❌ Expenses stream error: $error');
              _setError('Failed to load expenses: $error');
            },
          );

      print('✅ HISTORY PROVIDER - Streams started for community: $_communityId');
    } catch (e) {
      _setError('Failed to start data streams: $e');
      print('❌ HISTORY PROVIDER - Stream startup error: $e');
    }
  }

  Future<void> fetchOnce() async {
    if (_communityId == null || _communityId!.isEmpty) {
      _setError('Community ID is not available');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      print('🔄 HISTORY PROVIDER - Fetching initial data...');
      
      final results = await Future.wait([
        _contributionService.getCommunityContributions(_communityId!),
        _safeGetExpenses(_communityId!),
      ], eagerError: true);

      final contributions = results[0] as List<ContributionModel>;
      final expenses = results[1] as List<ExpenseModel>;

      print('📥 HISTORY PROVIDER - Fetched ${contributions.length} contributions, ${expenses.length} expenses');

      // Process both contributions and expenses together
      await _processIncoming(
        contributions: contributions,
        expenses: expenses,
        replaceAll: true,
      );

      _setLoading(false);
      print('✅ HISTORY PROVIDER - Initial data fetch completed');
    } catch (e) {
      _setLoading(false);
      _setError('Failed to load history data: $e');
      print('❌ HISTORY PROVIDER - Fetch error: $e');
    }
  }

  Future<List<ExpenseModel>> _safeGetExpenses(String communityId) async {
    try {
      return await _expenseService.getExpensesByCommunity(communityId);
    } catch (e) {
      print('⚠️ HISTORY PROVIDER - Could not load expenses: $e');
      return [];
    }
  }

  // Separate stream processing methods for better error handling
  void _processContributions(List<ContributionModel> contributions) {
    if (contributions.isNotEmpty) {
      _processIncoming(contributions: contributions);
    }
  }

  void _processExpenses(List<ExpenseModel> expenses) {
    if (expenses.isNotEmpty) {
      _processIncoming(expenses: expenses);
    }
  }

  Future<void> _processIncoming({
    List<ContributionModel>? contributions,
    List<ExpenseModel>? expenses,
    bool replaceAll = false,
  }) async {
    try {
      print('🔄 HISTORY PROVIDER - Processing incoming data...');
      print('   📥 Contributions: ${contributions?.length ?? 0}');
      print('   📥 Expenses: ${expenses?.length ?? 0}');

      // Create a copy of current items if not replacing all
      final Map<String, HistoryItem> itemsMap = replaceAll 
          ? {} 
          : {for (final item in _items) item.id: item};

      // Process contributions
      if (contributions != null && contributions.isNotEmpty) {
        await _processContributionsBatch(contributions, itemsMap);
      }

      // Process expenses
      if (expenses != null && expenses.isNotEmpty) {
        await _processExpensesBatch(expenses, itemsMap);
      }

      // Update items list
      _items = itemsMap.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      
      // Update filtered items
      _updateFilteredItems();

      print('✅ HISTORY PROVIDER - Processing completed:');
      print('   📊 Total items: ${_items.length}');
      print('   💰 Contributions: ${_items.where((i) => i.type == HistoryItemType.contribution).length}');
      print('   💸 Expenses: ${_items.where((i) => i.type == HistoryItemType.expense).length}');

      _safeNotifyListeners();
    } catch (e) {
      print('❌ HISTORY PROVIDER - Processing error: $e');
      _setError('Failed to process history data: $e');
    }
  }

  void _updateFilteredItems() { // ADD THIS METHOD
    List<HistoryItem> result = _items;

    // Apply type filter
    switch (_filterType) {
      case HistoryFilterType.contributions:
        result = result.where((i) => i.type == HistoryItemType.contribution).toList();
        break;
      case HistoryFilterType.expenses:
        result = result.where((i) => i.type == HistoryItemType.expense).toList();
        break;
      case HistoryFilterType.all:
      default:
        break;
    }

    // Apply program filter
    if (_selectedProgramId != null && _selectedProgramId!.isNotEmpty) {
      result = result.where((i) => i.programId == _selectedProgramId).toList();
    }

    // Apply date range filter
    if (_startDate != null) {
      result = result.where((i) => i.date.isAfter(_startDate!.subtract(const Duration(days: 1))) || 
                                  i.date.isAtSameMomentAs(_startDate!)).toList();
    }
    if (_endDate != null) {
      result = result.where((i) => i.date.isBefore(_endDate!.add(const Duration(days: 1))) || 
                                  i.date.isAtSameMomentAs(_endDate!)).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((item) {
        final titleMatch = item.title.toLowerCase().contains(_searchQuery);
        final subtitleMatch = item.subtitle.toLowerCase().contains(_searchQuery);
        final amountMatch = item.amount.toString().contains(_searchQuery);
        final categoryMatch = item.category?.toLowerCase().contains(_searchQuery) ?? false;
        final paymentMethodMatch = item.paymentMethod?.toLowerCase().contains(_searchQuery) ?? false;

        return titleMatch || subtitleMatch || amountMatch || categoryMatch || paymentMethodMatch;
      }).toList();
    }

    _filteredItems = result;
  }

  Future<void> _processContributionsBatch(
    List<ContributionModel> contributions,
    Map<String, HistoryItem> itemsMap,
  ) async {
    print('   🔄 Processing ${contributions.length} contributions...');

    for (final contribution in contributions) {
      try {
        await _processSingleContribution(contribution, itemsMap);
      } catch (error) {
        print('   ❌ Error processing contribution ${contribution.contributionId}: $error');
      }
    }
  }

  Future<void> _processExpensesBatch(
    List<ExpenseModel> expenses,
    Map<String, HistoryItem> itemsMap,
  ) async {
    print('   🔄 Processing ${expenses.length} expenses...');

    for (final expense in expenses) {
      try {
        await _processSingleExpense(expense, itemsMap);
      } catch (error) {
        print('   ❌ Error processing expense ${expense.expenseId}: $error');
      }
    }
  }

  Future<void> _processSingleContribution(
    ContributionModel contribution,
    Map<String, HistoryItem> itemsMap,
  ) async {
    final id = 'contrib_${contribution.contributionId}';
    
    // Safely parse date
    DateTime date;
    try {
      if (contribution.createdAt is Timestamp) {
        date = (contribution.createdAt as Timestamp).toDate();
      } else if (contribution.createdAt is DateTime) {
        date = contribution.createdAt as DateTime;
      } else {
        date = DateTime.now();
      }
    } catch (e) {
      date = DateTime.now();
    }

    // Get additional data in parallel
    final results = await Future.wait([
      _getProgramTitle(contribution.programId),
      _getUserName(contribution.userId),
    ], eagerError: false);

    final programTitle = results[0] as String?;
    final userName = results[1] as String?;

    itemsMap[id] = HistoryItem(
      id: id,
      type: HistoryItemType.contribution,
      title: '${ contribution.contributorName ?? 'Unknown'}',
      subtitle: programTitle ?? 'Contribution',
      amount: contribution.amount,
      date: date,
      userId: contribution.userId,
      contributorName: contribution.contributorName,
      programId: contribution.programId,
      paymentMethod: contribution.paymentMethod,
      original: contribution,
    );
  }

 Future<void> _processSingleExpense(
  ExpenseModel expense,
  Map<String, HistoryItem> itemsMap,
) async {
  final id = 'expense_${expense.expenseId}';
  final paidByName = await _getUserName(expense.paidBy);
  final programName = await _getProgramName(expense.programId); // Add this

  itemsMap[id] = HistoryItem(
    id: id,
    type: HistoryItemType.expense,
    title: expense.title.isNotEmpty ? expense.title : 'Expense',
    subtitle: '${programName ?? expense.programId} • Paid by ${paidByName ?? expense.paidBy ?? 'Unknown'}',
    amount: expense.amount,
    date: expense.expenseDate,
    userId: expense.paidBy,
    programId: expense.programId,
    category: expense.category,
    rawStatus: expense.status,
    original: expense,
  );
}

// Add this helper method
Future<String?> _getProgramName(String programId) async {
  try {
    // Assuming you have a ProgramService class
    final program = await ProgramService().getProgramById(programId);
    return program?.title;
  } catch (e) {
    print('Error fetching program name: $e');
    return null;
  }
}

  // ================= FILTER LOGIC ==================
  void setFilter(HistoryFilterType type) {
    if (_filterType != type && !_disposed) {
      _filterType = type;
      _updateFilteredItems();
      _safeNotifyListeners();
    }
  }

  void setProgramFilter(String? programId) {
    if (_selectedProgramId != programId && !_disposed) {
      _selectedProgramId = programId;
      _updateFilteredItems();
      _safeNotifyListeners();
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    if ((_startDate != start || _endDate != end) && !_disposed) {
      _startDate = start;
      _endDate = end;
      _updateFilteredItems();
      _safeNotifyListeners();
    }
  }

  void clearFilters() {
    if (!_disposed) {
      _filterType = HistoryFilterType.all;
      _selectedProgramId = null;
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _updateFilteredItems();
      _safeNotifyListeners();
    }
  }

  // === Search Methods ===
  void setSearchQuery(String query) {
    if (!_disposed) {
      final newQuery = query.trim().toLowerCase();
      if (_searchQuery != newQuery) {
        _searchQuery = newQuery;
        _updateFilteredItems();
        _safeNotifyListeners();
      }
    }
  }

  void clearSearch() {
    if (_searchQuery.isNotEmpty && !_disposed) {
      _searchQuery = '';
      _updateFilteredItems();
      _safeNotifyListeners();
    }
  }

  // ================= HELPER METHODS ==================
  Future<String?> _getProgramTitle(String? programId) async {
    if (programId == null || programId.isEmpty) return null;
    
    // Check cache first
    if (_programTitles.containsKey(programId)) {
      return _programTitles[programId];
    }

    try {
      final program = await _programService.getProgramById(programId);
      final title = program?.title ?? 'Unknown Program';
      _programTitles[programId] = title;
      return title;
    } catch (e) {
      print('⚠️ Error fetching program title for $programId: $e');
      _programTitles[programId] = 'Unknown Program';
      return 'Unknown Program';
    }
  }

  Future<String?> _getUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    
    // Check cache first
    if (_userNames.containsKey(userId)) {
      return _userNames[userId];
    }

    try {
      final user = await _userService.getUserById(userId);
      final name = user?.displayName ?? 
                  user?.email?.split('@').first ?? 
                  'Unknown User';
      _userNames[userId] = name;
      return name;
    } catch (e) {
      print('⚠️ Error fetching user name for $userId: $e');
      _userNames[userId] = 'Unknown User';
      return 'Unknown User';
    }
  }

  // ================= UTILITY METHODS ==================
  Map<String, List<HistoryItem>> get groupedByDate {
    final Map<String, List<HistoryItem>> groups = {};
    final DateFormat formatter = DateFormat.yMMMMd();

    for (final item in filteredItems) {
      final key = formatter.format(item.date);
      groups.putIfAbsent(key, () => []).add(item);
    }
    
    return groups;
  }

  // Get statistics
  Map<String, dynamic> get statistics {
    final contributions = _items.where((i) => i.type == HistoryItemType.contribution);
    final expenses = _items.where((i) => i.type == HistoryItemType.expense);

    return {
      'totalContributions': contributions.length,
      'totalExpenses': expenses.length,
      'totalContributionsAmount': contributions.fold(0.0, (sum, item) => sum + item.amount),
      'totalExpensesAmount': expenses.fold(0.0, (sum, item) => sum + item.amount),
      'netAmount': contributions.fold(0.0, (sum, item) => sum + item.amount) - 
                   expenses.fold(0.0, (sum, item) => sum + item.amount),
    };
  }

  // Refresh method for manual refresh
  Future<void> refresh() async {
    final user = _authProvider.user;

    if (user == null) {
      _items = [];
      _filteredItems = [];
      _safeNotifyListeners();
      return;
    }
    
    if (_communityId != null && _communityId!.isNotEmpty) {
      await fetchOnce();
    }
  }

  // Clear all data (useful for logout)
  void clearData() {
    if (!_disposed) {
      _items.clear();
      _filteredItems.clear();
      _programTitles.clear();
      _userNames.clear();
      _error = null;
      _isLoading = false;
      clearFilters();
      _safeNotifyListeners();
    }
  }

  void init() {
    // This method is now just a wrapper for the internal initialization
    // It's kept for backward compatibility with existing code
    print('📝 HISTORY PROVIDER - Manual init() called');
    _initializeFromAuth();
  }

  @override
  void dispose() {
    _disposed = true; // ADD THIS LINE
    _contribSub?.cancel();
    _expenseSub?.cancel();
    print('♻️ HISTORY PROVIDER - Disposed');
    super.dispose();
  }
}