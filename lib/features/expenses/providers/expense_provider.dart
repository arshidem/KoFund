import 'package:flutter/material.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/services/user_service.dart';
import '../../../features/auth/providers/app_auth_provider.dart';
import '../models/expense_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseService expenseService;
  final UserService userService;
  final AppAuthProvider appAuthProvider;

  ExpenseProvider({
    required this.expenseService,
    required this.userService,
    required this.appAuthProvider,
  });

  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> _EventExpenses = [];
  bool _isLoading = false;
  final Map<String, double> _expenseTotalsCache = {};
  
  // 🚀 OPTIMIZATION: List cache with TTL
  final Map<String, ({List<ExpenseModel> data, DateTime timestamp})> _listCache = {};
  final Duration _cacheTTL = const Duration(minutes: 5);

  List<ExpenseModel> get expenses => _expenses;
  List<ExpenseModel> get EventExpenses => _EventExpenses;
  bool get isLoading => _isLoading;

  /// Create new expense
  Future<void> createExpense(ExpenseModel expense) async {
    try {
      final currentUser = appAuthProvider.user;
      if (currentUser == null) {
        throw Exception('User must be logged in to add expenses');
      }

      // ✅ Check if user is in the event
      final isInEvent = await userService.isUserInEvent(currentUser.uid, expense.eventId);
      if (!isInEvent) {
        throw Exception('You must be a participant in this event to add expenses');
      }

      await expenseService.createExpense(expense);
      _expenseTotalsCache.clear();
      _listCache.clear(); // Invalidate list cache
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Load all expenses under a community
  Future<void> loadCommunityExpenses(String communityId, {bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _listCache.containsKey('community_$communityId')) {
      final cached = _listCache['community_$communityId']!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _expenses = cached.data;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();
    try {
      _expenses = await expenseService.getExpensesByCommunity(communityId);
      _listCache['community_$communityId'] = (data: _expenses, timestamp: DateTime.now());
    } catch (e) {
      debugPrint('Error loading community expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load expenses for a event
  Future<void> loadEventExpenses(String eventId, {bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _listCache.containsKey('event_$eventId')) {
      final cached = _listCache['event_$eventId']!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _EventExpenses = cached.data;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();
    try {
      _EventExpenses = await expenseService.getExpensesByEvent(eventId);
      _listCache['event_$eventId'] = (data: _EventExpenses, timestamp: DateTime.now());
    } catch (e) {
      debugPrint('Error loading event expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Add this method to your ExpenseProvider class
Future<void> updateExpense(
  ExpenseModel expense, {
  required String editedByUserId,
  required String editedByUserName,
  String? editReason,
}) async {
  try {
    debugPrint('📱 ExpenseProvider: Updating expense ${expense.expenseId}');
    
    // First, update in Firestore via service
    await expenseService.updateExpense(
      expense,
      editedByUserId: editedByUserId,
      editedByUserName: editedByUserName,
      editReason: editReason,
    );
    
    // Now update locally
    final index = _expenses.indexWhere(
      (e) => e.expenseId == expense.expenseId
    );
    
    if (index != -1) {
      // Update logic...
      final EventIndex = _EventExpenses.indexWhere(
        (e) => e.expenseId == expense.expenseId
      );
      if (EventIndex != -1) {
        _EventExpenses[EventIndex] = expense;
      }
      
      _expenses[index] = expense;
      _expenseTotalsCache.clear();
      _listCache.clear(); // Clear list cache on change
      notifyListeners();
      
      debugPrint('✅ ExpenseProvider: Local update successful');
    } else {
      debugPrint('⚠️ Warning: Expense not found in local list');
    }
    
  } catch (e) {
    debugPrint('❌ ExpenseProvider error: $e');
    rethrow;
  }
}

Future<void> updateExpenseWithHistory(
  String expenseId,
  Map<String, dynamic> updates,
) async {
  try {
    await FirebaseFirestore.instance
        .collection('expenses')
        .doc(expenseId)
        .update({
          ...updates,
          'updatedAt': Timestamp.now(),
        });
    _listCache.clear(); // Invalidate list cache
  } catch (e) {
    debugPrint('Error updating expense with history: $e');
    rethrow;
  }
}

Future<ExpenseModel?> getExpenseById(String expenseId) async {
  try {
    debugPrint('🔄 Getting expense by ID: $expenseId');
    final expense = await expenseService.getExpenseById(expenseId);
    if (expense == null) {
      debugPrint('❌ Expense not found with ID: $expenseId');
      return null;
    }
    debugPrint('✅ Found expense: ${expense.expenseId}');
    return expense;
  } catch (e) {
    debugPrint('❌ Error getting expense by ID: $e');
    return null;
  }
}

  /// Update expense status (approved, pending, rejected)
  Future<void> updateExpenseStatus(String expenseId, String status) async {
    try {
      await expenseService.updateExpenseStatus(expenseId, status);
      _expenseTotalsCache.clear();
      _listCache.clear(); // Clear list cache on change

      // Update local state
      final expenseIndex =
          _expenses.indexWhere((expense) => expense.expenseId == expenseId);
      if (expenseIndex != -1) {
        _expenses[expenseIndex] =
            _expenses[expenseIndex].copyWith(status: status);
      }

      final EventExpenseIndex =
          _EventExpenses.indexWhere((expense) => expense.expenseId == expenseId);
      if (EventExpenseIndex != -1) {
        _EventExpenses[EventExpenseIndex] =
            _EventExpenses[EventExpenseIndex].copyWith(status: status);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await expenseService.deleteExpense(expenseId);
      _expenseTotalsCache.clear();
      _listCache.clear(); // Clear list cache on change
      _expenses.removeWhere((expense) => expense.expenseId == expenseId);
      _EventExpenses.removeWhere((expense) => expense.expenseId == expenseId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Cached total for a event
  Future<double> getEventTotalExpenses(String eventId) async {
    final cacheKey = 'event_$eventId';
    if (_expenseTotalsCache.containsKey(cacheKey)) {
      return _expenseTotalsCache[cacheKey]!;
    }
    try {
      final total = await expenseService.getEventTotalExpenses(eventId);
      _expenseTotalsCache[cacheKey] = total;
      return total;
    } catch (e) {
      debugPrint('Error getting event total expenses: $e');
      return 0;
    }
  }

  /// Cached total for a community
  Future<double> getCommunityTotalExpenses(String communityId) async {
    final cacheKey = 'community_$communityId';
    if (_expenseTotalsCache.containsKey(cacheKey)) {
      return _expenseTotalsCache[cacheKey]!;
    }
    try {
      final total = await expenseService.getCommunityTotalExpenses(communityId);
      _expenseTotalsCache[cacheKey] = total;
      return total;
    } catch (e) {
      debugPrint('Error getting community total expenses: $e');
      return 0;
    }
  }

  /// Expenses by category
  Future<Map<String, double>> getEventExpensesByCategory(String eventId) async {
    try {
      return await expenseService.getEventExpensesByCategory(eventId);
    } catch (e) {
      debugPrint('Error getting expenses by category: $e');
      return {};
    }
  }

  /// Approved & pending filters
  List<ExpenseModel> getApprovedExpenses() =>
      _expenses.where((e) => e.status == 'approved').toList();

  List<ExpenseModel> getPendingExpenses() =>
      _expenses.where((e) => e.status == 'pending').toList();

  List<ExpenseModel> getApprovedEventExpenses() =>
      _EventExpenses.where((e) => e.status == 'approved').toList();

  List<ExpenseModel> getPendingEventExpenses() =>
      _EventExpenses.where((e) => e.status == 'pending').toList();

  /// Clear all cached data
  void clearCache() {
    _expenseTotalsCache.clear();
    _listCache.clear();
  }

  /// Real-time listeners
  Stream<List<ExpenseModel>> streamCommunityExpenses(String communityId) =>
      expenseService.streamCommunityExpenses(communityId);

  Stream<List<ExpenseModel>> streamEventExpenses(String eventId) =>
      expenseService.streamEventExpenses(eventId);

  Stream<double> streamEventTotalExpenses(String eventId) =>
      expenseService.streamTotalExpenses(eventId);

  Future<List<ExpenseModel>> getEventExpenses(String eventId) async {
    return await expenseService.getExpensesByEvent(eventId);
  }
}





