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
  String paidByName; // userId
  DateTime expenseDate;
  String status; // pending, approved, rejected
  Timestamp createdAt;
  
  // ✅ ADD: Entry tracking fields (who added this record)

  Timestamp? addedAt;

  // ✅ ADD: Edit tracking fields
  bool isEdited;
  String? lastEditedByUserId;
  String? lastEditedByUserName;
  Timestamp? lastEditedAt;
  String? editReason;
  
  // ✅ ADD: Edit history array to track all changes
  List<Map<String, dynamic>> editHistory;

  // ✅ ADD: Payment receipt tracking
  String? receiptUrl;
  String? receiptFileName;

  // ✅ ADD: Additional metadata
  String? referenceNumber;
  String? vendorName;
  String? paymentMethod; // cash, bank_transfer, upi, cheque, etc.

  ExpenseModel({
    required this.expenseId,
    required this.programId,
    required this.communityId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.paidByName,
    required this.expenseDate,
    required this.status,
    required this.createdAt,
    
    // New fields with defaults

    this.addedAt,
    this.isEdited = false,
    this.lastEditedByUserId,
    this.lastEditedByUserName,
    this.lastEditedAt,
    this.editReason,
    this.editHistory = const [],
    this.receiptUrl,
    this.receiptFileName,
    this.referenceNumber,
    this.vendorName,
    this.paymentMethod,
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
      paidByName: map['paidByName'] ?? '',
      expenseDate: (map['expenseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      
      // New fields
   
      addedAt: map['addedAt'] as Timestamp?,
      isEdited: map['isEdited'] == true,
      lastEditedByUserId: map['lastEditedByUserId'],
      lastEditedByUserName: map['lastEditedByUserName'],
      lastEditedAt: map['lastEditedAt'] as Timestamp?,
      editReason: map['editReason'],
      editHistory: (map['editHistory'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      receiptUrl: map['receiptUrl'],
      receiptFileName: map['receiptFileName'],
      referenceNumber: map['referenceNumber'],
      vendorName: map['vendorName'],
      paymentMethod: map['paymentMethod'],
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
      'paidByName': paidByName,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'status': status,
      'createdAt': createdAt,
      
      // New fields

      'addedAt': addedAt,
      'isEdited': isEdited,
      'lastEditedByUserId': lastEditedByUserId,
      'lastEditedByUserName': lastEditedByUserName,
      'lastEditedAt': lastEditedAt,
      'editReason': editReason,
      'editHistory': editHistory,
      'receiptUrl': receiptUrl,
      'receiptFileName': receiptFileName,
      'referenceNumber': referenceNumber,
      'vendorName': vendorName,
      'paymentMethod': paymentMethod,
    }..removeWhere((key, value) => value == null);
  }

  ExpenseModel copyWith({
    String? expenseId,
    String? programId,
    String? communityId,
    String? title,
    String? description,
    double? amount,
    String? category,
    String? paidBy,
    String? paidByName,
    DateTime? expenseDate,
    String? status,
    Timestamp? createdAt,

    Timestamp? addedAt,
    bool? isEdited,
    String? lastEditedByUserId,
    String? lastEditedByUserName,
    Timestamp? lastEditedAt,
    String? editReason,
    List<Map<String, dynamic>>? editHistory,
    String? receiptUrl,
    String? receiptFileName,
    String? referenceNumber,
    String? vendorName,
    String? paymentMethod,
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
      paidByName: paidByName ?? this.paidByName,
      expenseDate: expenseDate ?? this.expenseDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,

      addedAt: addedAt ?? this.addedAt,
      isEdited: isEdited ?? this.isEdited,
      lastEditedByUserId: lastEditedByUserId ?? this.lastEditedByUserId,
      lastEditedByUserName: lastEditedByUserName ?? this.lastEditedByUserName,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      editReason: editReason ?? this.editReason,
      editHistory: editHistory ?? this.editHistory,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptFileName: receiptFileName ?? this.receiptFileName,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      vendorName: vendorName ?? this.vendorName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}