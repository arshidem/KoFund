// lib/core/services/expense_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/expenses/models/expense_model.dart';

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
          .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
          .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load community expenses: $e');
    }
  }

  // Get expense by ID
  Future<ExpenseModel?> getExpenseById(String expenseId) async {
    try {
      final doc = await _firestore.collection('expenses').doc(expenseId).get();
      if (doc.exists) {
        return ExpenseModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to load expense: $e');
    }
  }

  // Update expense
  Future<void> updateExpense(String expenseId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).update(updates);
    } catch (e) {
      throw Exception('Failed to update expense: $e');
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
            .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
            .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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