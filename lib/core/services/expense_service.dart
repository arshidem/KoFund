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

  // Get expenses by event
  Future<List<ExpenseModel>> getExpensesByEvent(String eventId, {int limit = 20, String? communityId}) async {
    try {
      var query = _firestore
          .collection('expenses')
          .where('eventId', isEqualTo: eventId);

      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      final snapshot = await query
          .limit(limit)
          .get();

      final docs = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      
      // Sort in memory to avoid index requirement
      docs.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return docs;
    } catch (e) {
      throw Exception('Failed to load event expenses: $e');
    }
  }

  // Get expenses by community
  Future<List<ExpenseModel>> getExpensesByCommunity(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('communityId', isEqualTo: communityId)
          .get();

      final docs = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
          
      // Sort in memory
      docs.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return docs;
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
    
    // 🚀 OPTIMIZATION: We could skip the existence check if we use update() directly,
    // but the business logic here requires change detection for the history log.
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
    
    if (currentExpense.eventId != expense.eventId) {
      changes['eventId'] = {
        'old': currentExpense.eventId,
        'new': expense.eventId,
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
        'eventId': expense.eventId,
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

  // Get total expenses for a event
  Future<double> getEventTotalExpenses(String eventId, {String? communityId}) async {
    try {
      var query = _firestore
          .collection('expenses')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'approved');

      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      // 🚀 OPTIMIZATION: Use aggregate query (sum)
      final aggregateQuery = await query.aggregate(sum('amount')).get();
      return (aggregateQuery.getSum('amount') ?? 0).toDouble();
    } catch (e) {
      debugPrint('⚠️ Aggregation failed for event expenses, falling back to manual sum: $e');
      final expenses = await getExpensesByEvent(eventId, limit: 1000, communityId: communityId);
      return expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);
    }
  }

  // Get total expenses for a community
  Future<double> getCommunityTotalExpenses(String communityId) async {
    try {
      // 🚀 OPTIMIZATION: Use aggregate query (sum)
      final aggregateQuery = await _firestore
          .collection('expenses')
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'approved')
          .aggregate(sum('amount'))
          .get();
      return (aggregateQuery.getSum('amount') ?? 0).toDouble();
    } catch (e) {
      debugPrint('⚠️ Aggregation failed for community expenses, falling back to manual sum: $e');
      final expenses = await getExpensesByCommunity(communityId);
      return expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);
    }
  }

  // Stream expenses for real-time updates
  Stream<List<ExpenseModel>> streamEventExpenses(String eventId, {String? communityId}) {
    var query = _firestore
        .collection('expenses')
        .where('eventId', isEqualTo: eventId);

    if (communityId != null && communityId.isNotEmpty) {
      query = query.where('communityId', isEqualTo: communityId);
    }

    return query.snapshots().map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      docs.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return docs;
    });
  }

  Future<List<ExpenseModel>> getMonthlyExpenses(String eventId, String monthId, {String? communityId}) async {
    try {
      var query = _firestore
          .collection('expenses')
          .where('eventId', isEqualTo: eventId)
          .where('monthId', isEqualTo: monthId);

      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      docs.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return docs;
    } catch (e) {
      debugPrint('❌ Error loading monthly expenses: $e');
      return [];
    }
  }

  Stream<List<ExpenseModel>> streamMonthlyExpenses(String eventId, String monthId, {String? communityId}) {
    var query = _firestore
        .collection('expenses')
        .where('eventId', isEqualTo: eventId)
        .where('monthId', isEqualTo: monthId);

    if (communityId != null && communityId.isNotEmpty) {
      query = query.where('communityId', isEqualTo: communityId);
    }

    return query.snapshots().map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      docs.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return docs;
    });
  }

  // Stream community expenses for real-time updates
  Stream<List<ExpenseModel>> streamCommunityExpenses(String communityId) {
    return _firestore
        .collection('expenses')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList();
          
          // Sort in memory
          docs.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
          return docs;
        });
  }

  // Stream total expenses amount for real-time updates
  Stream<double> streamTotalExpenses(String eventId, {String? communityId}) {
    var query = _firestore
        .collection('expenses')
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'approved');

    if (communityId != null && communityId.isNotEmpty) {
      query = query.where('communityId', isEqualTo: communityId);
    }

    return query.snapshots().map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      return total;
    });
  }
}





