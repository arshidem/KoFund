// lib/core/services/expense_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/expenses/models/expense_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;
class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create new expense
  Future<String> createExpense(ExpenseModel expense) async {
    try {
      final docRef = await _firestore.collection('expenses').add(expense.toMap());
      await docRef.update({'expenseId': docRef.id});
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create expense: $e');
    }
  }

  // Get expenses by program
  Future<List<ExpenseModel>> getExpensesByProgram(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('programId', isEqualTo: programId)
          .orderBy('expenseDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load program expenses: $e');
    }
  }

  // Get expenses by community
  Future<List<ExpenseModel>> getExpensesByCommunity(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('communityId', isEqualTo: communityId)
          .orderBy('expenseDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load community expenses: $e');
    }
  }



// Add this method to your ExpenseService class
Future<void> updateExpense(
  ExpenseModel expense, {
  required String editedByUserId,
  required String editedByUserName,
  String? editReason,
}) async {
  try {
    // Get document reference
    final docRef = _firestore
        .collection('expenses')
        .doc(expense.expenseId);
    
    final snapshot = await docRef.get();
    
    if (!snapshot.exists) {
      throw Exception('Expense document not found');
    }
    
    final currentData = snapshot.data();
    
    if (currentData == null) {
      throw Exception('Document has no data');
    }
    
    final currentExpense = ExpenseModel.fromMap(currentData, snapshot.id);
    
    // Detect changes
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
      changes['programId'] = {
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
    
    // Only add edit history if there are actual changes
    if (changes.isNotEmpty) {
      // Get existing edit history
      List<dynamic> existingHistory = [];
      final historyData = currentData['editHistory'];
      if (historyData is List) {
        existingHistory = List<dynamic>.from(historyData);
      }
      
      // Add new edit record
      final editRecord = {
        'editedAt': Timestamp.now(),
        'editedByUserId': editedByUserId,
        'editedByUserName': editedByUserName,
        'changes': changes,
        'reason': editReason ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final updatedHistory = List<dynamic>.from(existingHistory)..add(editRecord);
      
      // Prepare update data
      final updateData = {
        'title': expense.title,
        'description': expense.description,
        'amount': expense.amount,
        'programId': expense.programId,
        'category': expense.category,
        'paymentMethod': expense.paymentMethod,
        'expenseDate': Timestamp.fromDate(expense.expenseDate),
        'vendorName': expense.vendorName,
        'referenceNumber': expense.referenceNumber,
        
        // Edit tracking
        'isEdited': true,
        'lastEditedByUserId': editedByUserId,
        'lastEditedByUserName': editedByUserName,
        'lastEditedAt': Timestamp.now(),
        'editReason': editReason,
        'editHistory': updatedHistory,
        'updatedAt': Timestamp.now(),
      };
      
      // Remove null values
      final cleanUpdateData = Map<String, dynamic>.from(updateData)
        ..removeWhere((key, value) => value == null);
      
      await docRef.update(cleanUpdateData);
    } else {
      // If no changes, just update the timestamp
      await docRef.update({
        'updatedAt': Timestamp.now(),
      });
    }
    
  } catch (e) {
    throw Exception('Failed to update expense: $e');
  }
}
Future<ExpenseModel?> getExpenseById(String expenseId) async {
  try {
    debugPrint('🔄 ExpenseService: Getting expense by ID: $expenseId');
    
    // Try with the given ID first
    var docRef = _firestore
        .collection('expenses')
        .doc(expenseId);
    
    var snapshot = await docRef.get();
    
    // If not found, try adding 'expense_' prefix
    if (!snapshot.exists && !expenseId.startsWith('expense_')) {
      debugPrint('⚠️ Not found, trying with "expense_" prefix...');
      docRef = _firestore
          .collection('expenses')
          .doc('expense_$expenseId');
      snapshot = await docRef.get();
    }
    
    if (!snapshot.exists) {
      debugPrint('❌ Expense not found with ID: $expenseId');
      return null;
    }
    
    final data = snapshot.data();
    if (data == null) {
      debugPrint('❌ Expense data is invalid or null');
      return null;
    }
    
    debugPrint('✅ Found expense: ${snapshot.id}');
    return ExpenseModel.fromMap(data, snapshot.id);
    
  } catch (e) {
    debugPrint('❌ Error getting expense by ID in service: $e');
    return null;
  }
}
  // Update expense status
  Future<void> updateExpenseStatus(String expenseId, String status) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to update expense status: $e');
    }
  }

  // Delete expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).delete();
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Get total expenses for a program
  Future<double> getProgramTotalExpenses(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'approved')
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate program expenses: $e');
    }
  }

  // Get total expenses for a community
  Future<double> getCommunityTotalExpenses(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'approved')
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate community expenses: $e');
    }
  }

  // Get expenses by category for a program
  Future<Map<String, double>> getProgramExpensesByCategory(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'approved')
          .get();

      final Map<String, double> categoryTotals = {};
      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] ?? 'Other';
        final amount = (doc.data()['amount'] ?? 0).toDouble();
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }
      return categoryTotals;
    } catch (e) {
      throw Exception('Failed to get expenses by category: $e');
    }
  }

  // Stream expenses for real-time updates
  Stream<List<ExpenseModel>> streamProgramExpenses(String programId) {
    return _firestore
        .collection('expenses')
        .where('programId', isEqualTo: programId)
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream community expenses for real-time updates
  Stream<List<ExpenseModel>> streamCommunityExpenses(String communityId) {
    return _firestore
        .collection('expenses')
        .where('communityId', isEqualTo: communityId)
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream total expenses amount for real-time updates
  Stream<double> streamProgramTotalExpenses(String programId) {
    return _firestore
        .collection('expenses')
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    });
  }
}

