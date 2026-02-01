import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  List<ExpenseModel> _programExpenses = [];
  bool _isLoading = false;
  final Map<String, double> _expenseTotalsCache = {};

  List<ExpenseModel> get expenses => _expenses;
  List<ExpenseModel> get programExpenses => _programExpenses;
  bool get isLoading => _isLoading;

  /// Create new expense
  Future<void> createExpense(ExpenseModel expense) async {
    try {
      final currentUser = appAuthProvider.user;
      if (currentUser == null) {
        throw Exception('User must be logged in to add expenses');
      }

      // ✅ Check if user is in the program
      final isInProgram = await userService.isUserInProgram(currentUser.uid, expense.programId);
      if (!isInProgram) {
        throw Exception('You must be a participant in this program to add expenses');
      }

      await expenseService.createExpense(expense);
      _expenseTotalsCache.clear(); // Invalidate cache
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Load all expenses under a community
  Future<void> loadCommunityExpenses(String communityId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _expenses = await expenseService.getExpensesByCommunity(communityId);
    } catch (e) {
      debugPrint('Error loading community expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load expenses for a program
  Future<void> loadProgramExpenses(String programId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _programExpenses = await expenseService.getExpensesByProgram(programId);
    } catch (e) {
      debugPrint('Error loading program expenses: $e');
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
      // Get current version for comparison
      final currentExpense = _expenses[index];
      
      // Detect changes locally
      final Map<String, Map<String, dynamic>> changes = {};
      
      if (currentExpense.amount != expense.amount) {
        changes['amount'] = {
          'old': currentExpense.amount,
          'new': expense.amount,
        };
      }
      
      if (currentExpense.title != expense.title) {
        changes['title'] = {
          'old': currentExpense.title,
          'new': expense.title,
        };
      }
      
      if (currentExpense.description != expense.description) {
        changes['description'] = {
          'old': currentExpense.description,
          'new': expense.description,
        };
      }
      
      if (currentExpense.programId != expense.programId) {
        changes['program'] = {
          'old': currentExpense.programId,
          'new': expense.programId,
        };
      }
      
      if (currentExpense.category != expense.category) {
        changes['category'] = {
          'old': currentExpense.category,
          'new': expense.category,
        };
      }
      
      if (currentExpense.paymentMethod != expense.paymentMethod) {
        changes['paymentMethod'] = {
          'old': currentExpense.paymentMethod ?? 'Not set',
          'new': expense.paymentMethod ?? 'Not set',
        };
      }
      
      // Update program expenses list too
      final programIndex = _programExpenses.indexWhere(
        (e) => e.expenseId == expense.expenseId
      );
      if (programIndex != -1) {
        _programExpenses[programIndex] = expense;
      }
      
      _expenses[index] = expense;
      _expenseTotalsCache.clear();
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
// Add this to your ExpenseProvider class
// In your ExpenseProvider class
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
  } catch (e) {
    debugPrint('Error updating expense with history: $e');
    rethrow;
  }
}
// Add this method to your ExpenseProvider class (after the existing methods)
Future<ExpenseModel?> getExpenseById(String expenseId) async {
  try {
    debugPrint('🔄 Getting expense by ID: $expenseId');
    
    // Use the expenseService to fetch the expense
    // If your expenseService doesn't have this method, you'll need to add it
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

      // Update local state
      final expenseIndex =
          _expenses.indexWhere((expense) => expense.expenseId == expenseId);
      if (expenseIndex != -1) {
        _expenses[expenseIndex] =
            _expenses[expenseIndex].copyWith(status: status);
      }

      final programExpenseIndex =
          _programExpenses.indexWhere((expense) => expense.expenseId == expenseId);
      if (programExpenseIndex != -1) {
        _programExpenses[programExpenseIndex] =
            _programExpenses[programExpenseIndex].copyWith(status: status);
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
      _expenses.removeWhere((expense) => expense.expenseId == expenseId);
      _programExpenses.removeWhere((expense) => expense.expenseId == expenseId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Cached total for a program
  Future<double> getProgramTotalExpenses(String programId) async {
    final cacheKey = 'program_$programId';
    if (_expenseTotalsCache.containsKey(cacheKey)) {
      return _expenseTotalsCache[cacheKey]!;
    }
    try {
      final total = await expenseService.getProgramTotalExpenses(programId);
      _expenseTotalsCache[cacheKey] = total;
      return total;
    } catch (e) {
      debugPrint('Error getting program total expenses: $e');
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
  Future<Map<String, double>> getProgramExpensesByCategory(String programId) async {
    try {
      return await expenseService.getProgramExpensesByCategory(programId);
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

  List<ExpenseModel> getApprovedProgramExpenses() =>
      _programExpenses.where((e) => e.status == 'approved').toList();

  List<ExpenseModel> getPendingProgramExpenses() =>
      _programExpenses.where((e) => e.status == 'pending').toList();

  /// Clear all cached totals
  void clearCache() => _expenseTotalsCache.clear();

  /// Real-time listeners
  Stream<List<ExpenseModel>> streamCommunityExpenses(String communityId) =>
      expenseService.streamCommunityExpenses(communityId);

  Stream<List<ExpenseModel>> streamProgramExpenses(String programId) =>
      expenseService.streamProgramExpenses(programId);

  Stream<double> streamProgramTotalExpenses(String programId) =>
      expenseService.streamProgramTotalExpenses(programId);
}

