// lib/features/expenses/models/expense_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  String expenseId;
  String eventId;
  String communityId;
  String title;
  String description;
  double amount;
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
  
  // ✅ ADD: Monthly fields
  final String? monthId;
  final bool isMonthlyExpense;

  ExpenseModel({
    required this.expenseId,
    required this.eventId,
    required this.communityId,
    required this.title,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    required this.expenseDate,
    required this.status,
    required this.createdAt,
    this.monthId,
    this.isMonthlyExpense = false,
    this.vendorName,
    
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
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ExpenseModel(
      expenseId: documentId,
      eventId: map['eventId'] ?? '',
      communityId: map['communityId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paidBy: map['paidBy'] ?? '',
      paidByName: map['paidByName'] ?? '',
      expenseDate: (map['expenseDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      monthId: map['monthId'],
      isMonthlyExpense: map['isMonthlyExpense'] ?? false,
      vendorName: map['vendorName'],
      
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'communityId': communityId,
      'title': title,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'status': status,
      'createdAt': createdAt,
      'monthId': monthId,
      'isMonthlyExpense': isMonthlyExpense,
      'vendorName': vendorName,
      
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
    }..removeWhere((key, value) => value == null);
  }

  ExpenseModel copyWith({
    String? expenseId,
    String? eventId,
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
    String? monthId,
    bool? isMonthlyExpense,
    String? vendorName,
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
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      eventId: eventId ?? this.eventId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      paidByName: paidByName ?? this.paidByName,
      expenseDate: expenseDate ?? this.expenseDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      monthId: monthId ?? this.monthId,
      isMonthlyExpense: isMonthlyExpense ?? this.isMonthlyExpense,
      vendorName: vendorName ?? this.vendorName,
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
    );
  }
}





