// lib/features/expenses/models/expense_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  String expenseId;
  String programId;
  String communityId;
  String title;
  String description;
  double amount;
  String category;
  String paidBy; // userId
  DateTime expenseDate;
  String status; // pending, approved, rejected
  Timestamp createdAt;

  ExpenseModel({
    required this.expenseId,
    required this.programId,
    required this.communityId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.expenseDate,
    required this.status,
    required this.createdAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ExpenseModel(
      expenseId: documentId,
      programId: map['programId'] ?? '',
      communityId: map['communityId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      paidBy: map['paidBy'] ?? '',
      expenseDate: (map['expenseDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'programId': programId,
      'communityId': communityId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'paidBy': paidBy,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'status': status,
      'createdAt': createdAt,
    };
  }

  // ✅ Add copyWith method
  ExpenseModel copyWith({
    String? expenseId,
    String? programId,
    String? communityId,
    String? title,
    String? description,
    double? amount,
    String? category,
    String? paidBy,
    DateTime? expenseDate,
    String? status,
    Timestamp? createdAt,
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      programId: programId ?? this.programId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      expenseDate: expenseDate ?? this.expenseDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
