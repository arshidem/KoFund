// 📁 lib/models/deleted_contribution_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'contribution_model.dart'; // Your existing model

class DeletedContributionModel {
  // 🔹 Deletion Record ID (NEW - separate from original)
  String deletedContributionId;
  
  // 🔹 Original Contribution Reference
  String originalContributionId;
  
  // 🔹 COPY of ALL Original Contribution Data
  String programId;
  String userId;
  String contributorName;
  String communityId;
  double amount;
  String paymentMethod;
  String status;
  Timestamp createdAt;
  
  // 🔹 Monthly Contribution Fields
  bool isMonthlyContribution;
  String? monthId;
  
  // 🔹 Entry Tracking Fields
  String? addedByUserId;
  String? addedByUserName;
  Timestamp? addedAt;
  
  // 🔹 Edit Tracking Fields
  bool isEdited;
  String? lastEditedByUserId;
  String? lastEditedByUserName;
  Timestamp? lastEditedAt;
  String? editReason;
  List<Map<String, dynamic>> editHistory;
  
  // 🔹 DELETION SPECIFIC FIELDS
  String deletedByUserId;
  String deletedByUserName;
  Timestamp deletedAt;
  String deletionReason;
  
  // 🔹 TTL (Time-To-Live) Field - CRITICAL FOR AUTO-DELETION
  Timestamp ttlExpiresAt; // Firestore will auto-delete when this time passes
  
  // 🔹 Status Tracking Fields
  bool isRestored;
  String? restoredByUserId;
  String? restoredByUserName;
  Timestamp? restoredAt;
  
  // 🔹 Metadata for Tracking
  String? cleanupTrigger;
  Timestamp? permanentlyDeletedAt;
  bool? wasAutoDeleted;

  DeletedContributionModel({
    // Deletion Record ID
    required this.deletedContributionId,
    required this.originalContributionId,
    
    // Original Contribution Data
    required this.programId,
    required this.userId,
    required this.contributorName,
    required this.communityId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    
    // Monthly Fields
    this.isMonthlyContribution = false,
    this.monthId,
    
    // Entry Tracking
    this.addedByUserId,
    this.addedByUserName,
    this.addedAt,
    
    // Edit Tracking
    this.isEdited = false,
    this.lastEditedByUserId,
    this.lastEditedByUserName,
    this.lastEditedAt,
    this.editReason,
    this.editHistory = const [],
    
    // Deletion Fields
    required this.deletedByUserId,
    required this.deletedByUserName,
    required this.deletedAt,
    required this.deletionReason,
    
    // TTL Field - Required for auto-deletion
    required this.ttlExpiresAt,
    
    // Status Tracking
    this.isRestored = false,
    this.restoredByUserId,
    this.restoredByUserName,
    this.restoredAt,
    
    // Metadata
    this.cleanupTrigger,
    this.permanentlyDeletedAt,
    this.wasAutoDeleted = false,
  });

  // 🔹 FACTORY: Create from ContributionModel (When Admin deletes)
  factory DeletedContributionModel.fromContributionModel({
    required ContributionModel contribution,
    required String deletedByUserId,
    required String deletedByUserName,
    required String deletionReason,
  }) {
    // Generate unique ID for deleted record
    final deletedId = 'deleted_${contribution.contributionId}_${DateTime.now().millisecondsSinceEpoch}';
    
    // Calculate TTL expiry (30 days from now)
    final ttlExpiry = Timestamp.fromDate(
      DateTime.now().add(Duration(days: 30))
    );
    
    return DeletedContributionModel(
      deletedContributionId: deletedId,
      originalContributionId: contribution.contributionId,
      
      // Copy all original contribution data
      programId: contribution.programId,
      userId: contribution.userId,
      contributorName: contribution.contributorName,
      communityId: contribution.communityId,
      amount: contribution.amount,
      paymentMethod: contribution.paymentMethod,
      status: contribution.status,
      createdAt: contribution.createdAt,
      
      isMonthlyContribution: contribution.isMonthlyContribution,
      monthId: contribution.monthId,
      
      addedByUserId: contribution.addedByUserId,
      addedByUserName: contribution.addedByUserName,
      addedAt: contribution.addedAt,
      
      isEdited: contribution.isEdited,
      lastEditedByUserId: contribution.lastEditedByUserId,
      lastEditedByUserName: contribution.lastEditedByUserName,
      lastEditedAt: contribution.lastEditedAt,
      editReason: contribution.editReason,
      editHistory: List.from(contribution.editHistory),
      
      // Deletion info
      deletedByUserId: deletedByUserId,
      deletedByUserName: deletedByUserName,
      deletedAt: Timestamp.now(),
      deletionReason: deletionReason,
      
      // TTL - Critical for auto-deletion
      ttlExpiresAt: ttlExpiry,
      
      // Default status
      isRestored: false,
      wasAutoDeleted: false,
    );
  }

  // 🔹 FACTORY: Create from Firestore Document
  factory DeletedContributionModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    
    return DeletedContributionModel.fromMap(data, id);
  }

  // 🔹 FACTORY: Create from Map (Firestore data)
  factory DeletedContributionModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    // Parse editHistory
    final editHistoryData = map['editHistory'];
    List<Map<String, dynamic>> parsedEditHistory = [];
    
    if (editHistoryData is List) {
      for (var item in editHistoryData) {
        if (item is Map<String, dynamic>) {
          parsedEditHistory.add(Map<String, dynamic>.from(item));
        }
      }
    }
    
    return DeletedContributionModel(
      deletedContributionId: id,
      originalContributionId: map['originalContributionId'] ?? '',
      
      // Original contribution data
      programId: map['programId'] ?? '',
      userId: map['userId'] ?? '',
      contributorName: map['contributorName'] ?? '',
      communityId: map['communityId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      status: map['status'] ?? 'completed',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      
      isMonthlyContribution: map['isMonthlyContribution'] ?? false,
      monthId: map['monthId'],
      
      addedByUserId: map['addedByUserId'],
      addedByUserName: map['addedByUserName'],
      addedAt: map['addedAt'],
      
      isEdited: map['isEdited'] ?? false,
      lastEditedByUserId: map['lastEditedByUserId'],
      lastEditedByUserName: map['lastEditedByUserName'],
      lastEditedAt: map['lastEditedAt'],
      editReason: map['editReason'],
      editHistory: parsedEditHistory,
      
      // Deletion info
      deletedByUserId: map['deletedByUserId'] ?? '',
      deletedByUserName: map['deletedByUserName'] ?? '',
      deletedAt: map['deletedAt'] ?? Timestamp.now(),
      deletionReason: map['deletionReason'] ?? '',
      
      // TTL - Must exist for auto-deletion
      ttlExpiresAt: map['ttlExpiresAt'] ?? 
        Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
      
      // Status tracking
      isRestored: map['isRestored'] ?? false,
      restoredByUserId: map['restoredByUserId'],
      restoredByUserName: map['restoredByUserName'],
      restoredAt: map['restoredAt'],
      
      // Metadata
      cleanupTrigger: map['cleanupTrigger'],
      permanentlyDeletedAt: map['permanentlyDeletedAt'],
      wasAutoDeleted: map['wasAutoDeleted'] ?? false,
    );
  }

  // 🔹 Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'originalContributionId': originalContributionId,
      
      // Original contribution data
      'programId': programId,
      'userId': userId,
      'contributorName': contributorName,
      'communityId': communityId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt,
      
      'isMonthlyContribution': isMonthlyContribution,
      'monthId': monthId,
      
      'addedByUserId': addedByUserId,
      'addedByUserName': addedByUserName,
      'addedAt': addedAt,
      
      'isEdited': isEdited,
      'lastEditedByUserId': lastEditedByUserId,
      'lastEditedByUserName': lastEditedByUserName,
      'lastEditedAt': lastEditedAt,
      'editReason': editReason,
      'editHistory': editHistory,
      
      // Deletion info
      'deletedByUserId': deletedByUserId,
      'deletedByUserName': deletedByUserName,
      'deletedAt': deletedAt,
      'deletionReason': deletionReason,
      
      // 🔹 TTL FIELD - REQUIRED FOR AUTO-DELETION
      'ttlExpiresAt': ttlExpiresAt,
      
      // Status tracking
      'isRestored': isRestored,
      'restoredByUserId': restoredByUserId,
      'restoredByUserName': restoredByUserName,
      'restoredAt': restoredAt,
      
      // Metadata
      'cleanupTrigger': cleanupTrigger,
      'permanentlyDeletedAt': permanentlyDeletedAt,
      'wasAutoDeleted': wasAutoDeleted,
    };
  }

  // 🔹 Convert back to ContributionModel (for restoration)
  ContributionModel toContributionModel() {
    return ContributionModel(
      contributionId: originalContributionId, // Use original ID
      programId: programId,
      userId: userId,
      contributorName: contributorName,
      communityId: communityId,
      amount: amount,
      paymentMethod: paymentMethod,
      
      isMonthlyContribution: isMonthlyContribution,
      monthId: monthId,
      
      addedByUserId: addedByUserId,
      addedByUserName: addedByUserName,
      addedAt: addedAt,
      
      isEdited: isEdited,
      lastEditedByUserId: lastEditedByUserId,
      lastEditedByUserName: lastEditedByUserName,
      lastEditedAt: lastEditedAt,
      editReason: editReason,
      editHistory: List.from(editHistory),
      
      createdAt: createdAt,
    );
  }

  // 🔹 HELPER: Check if expired (for TTL)
  bool get isExpired {
    final now = DateTime.now();
    final expiryDate = ttlExpiresAt.toDate();
    return now.isAfter(expiryDate);
  }

  // 🔹 HELPER: Days until auto-deletion
  int get daysUntilAutoDeletion {
    final now = DateTime.now();
    final expiryDate = ttlExpiresAt.toDate();
    final difference = expiryDate.difference(now);
    return difference.inDays;
  }

  // 🔹 HELPER: Check if should show warning (3 days before)
  bool get shouldShowDeletionWarning {
    return daysUntilAutoDeletion <= 3 && daysUntilAutoDeletion >= 0;
  }

  // 🔹 HELPER: Formatted dates for UI
  String get formattedDeletedDate {
    return DateFormat('dd MMM yyyy, hh:mm a').format(deletedAt.toDate());
  }

  String get formattedTTLExpiry {
    return DateFormat('dd MMM yyyy').format(ttlExpiresAt.toDate());
  }

  String get formattedOriginalDate {
    return DateFormat('dd MMM yyyy').format(createdAt.toDate());
  }

  // 🔹 HELPER: Get deletion status message
  String get deletionStatusMessage {
    if (isRestored) {
      return '🔄 Restored on ${DateFormat('dd MMM yyyy').format(restoredAt!.toDate())}';
    }
    
    if (daysUntilAutoDeletion < 0) {
      return '🗑️ Auto-deleted';
    }
    
    if (shouldShowDeletionWarning) {
      return '⚠️ Auto-deletes in $daysUntilAutoDeletion days';
    }
    
    return '📝 Deleted - Auto-deletes in $daysUntilAutoDeletion days';
  }

  // 🔹 HELPER: Check if can be restored
  bool get canBeRestored {
    return !isRestored && !isExpired;
  }

  // 🔹 HELPER: Create a restore record
  DeletedContributionModel markAsRestored({
    required String restoredByUserId,
    required String restoredByUserName,
  }) {
    return DeletedContributionModel(
      deletedContributionId: deletedContributionId,
      originalContributionId: originalContributionId,
      programId: programId,
      userId: userId,
      contributorName: contributorName,
      communityId: communityId,
      amount: amount,
      paymentMethod: paymentMethod,
      status: status,
      createdAt: createdAt,
      isMonthlyContribution: isMonthlyContribution,
      monthId: monthId,
      addedByUserId: addedByUserId,
      addedByUserName: addedByUserName,
      addedAt: addedAt,
      isEdited: isEdited,
      lastEditedByUserId: lastEditedByUserId,
      lastEditedByUserName: lastEditedByUserName,
      lastEditedAt: lastEditedAt,
      editReason: editReason,
      editHistory: editHistory,
      deletedByUserId: deletedByUserId,
      deletedByUserName: deletedByUserName,
      deletedAt: deletedAt,
      deletionReason: deletionReason,
      ttlExpiresAt: ttlExpiresAt,
      isRestored: true,
      restoredByUserId: restoredByUserId,
      restoredByUserName: restoredByUserName,
      restoredAt: Timestamp.now(),
      cleanupTrigger: cleanupTrigger,
      permanentlyDeletedAt: permanentlyDeletedAt,
      wasAutoDeleted: wasAutoDeleted,
    );
  }

  // 🔹 EQUALITY CHECK
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeletedContributionModel &&
          runtimeType == other.runtimeType &&
          deletedContributionId == other.deletedContributionId;

  @override
  int get hashCode => deletedContributionId.hashCode;

  // 🔹 COPY WITH
  DeletedContributionModel copyWith({
    String? deletedContributionId,
    String? originalContributionId,
    String? programId,
    String? userId,
    String? contributorName,
    String? communityId,
    double? amount,
    String? paymentMethod,
    String? status,
    Timestamp? createdAt,
    bool? isMonthlyContribution,
    String? monthId,
    String? addedByUserId,
    String? addedByUserName,
    Timestamp? addedAt,
    bool? isEdited,
    String? lastEditedByUserId,
    String? lastEditedByUserName,
    Timestamp? lastEditedAt,
    String? editReason,
    List<Map<String, dynamic>>? editHistory,
    String? deletedByUserId,
    String? deletedByUserName,
    Timestamp? deletedAt,
    String? deletionReason,
    Timestamp? ttlExpiresAt,
    bool? isRestored,
    String? restoredByUserId,
    String? restoredByUserName,
    Timestamp? restoredAt,
    String? cleanupTrigger,
    Timestamp? permanentlyDeletedAt,
    bool? wasAutoDeleted,
  }) {
    return DeletedContributionModel(
      deletedContributionId: deletedContributionId ?? this.deletedContributionId,
      originalContributionId: originalContributionId ?? this.originalContributionId,
      programId: programId ?? this.programId,
      userId: userId ?? this.userId,
      contributorName: contributorName ?? this.contributorName,
      communityId: communityId ?? this.communityId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isMonthlyContribution: isMonthlyContribution ?? this.isMonthlyContribution,
      monthId: monthId ?? this.monthId,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedByUserName: addedByUserName ?? this.addedByUserName,
      addedAt: addedAt ?? this.addedAt,
      isEdited: isEdited ?? this.isEdited,
      lastEditedByUserId: lastEditedByUserId ?? this.lastEditedByUserId,
      lastEditedByUserName: lastEditedByUserName ?? this.lastEditedByUserName,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      editReason: editReason ?? this.editReason,
      editHistory: editHistory ?? this.editHistory,
      deletedByUserId: deletedByUserId ?? this.deletedByUserId,
      deletedByUserName: deletedByUserName ?? this.deletedByUserName,
      deletedAt: deletedAt ?? this.deletedAt,
      deletionReason: deletionReason ?? this.deletionReason,
      ttlExpiresAt: ttlExpiresAt ?? this.ttlExpiresAt,
      isRestored: isRestored ?? this.isRestored,
      restoredByUserId: restoredByUserId ?? this.restoredByUserId,
      restoredByUserName: restoredByUserName ?? this.restoredByUserName,
      restoredAt: restoredAt ?? this.restoredAt,
      cleanupTrigger: cleanupTrigger ?? this.cleanupTrigger,
      permanentlyDeletedAt: permanentlyDeletedAt ?? this.permanentlyDeletedAt,
      wasAutoDeleted: wasAutoDeleted ?? this.wasAutoDeleted,
    );
  }

  @override
  String toString() {
    return 'DeletedContributionModel{'
        'id: $deletedContributionId, '
        'originalId: $originalContributionId, '
        'user: $contributorName, '
        'amount: $amount, '
        'deletedBy: $deletedByUserName, '
        'expiresAt: ${ttlExpiresAt.toDate()}, '
        'daysLeft: $daysUntilAutoDeletion'
        '}';
  }
}

// 🔹 Constants for TTL Configuration
class TTLConfig {
  static const int daysUntilAutoDelete = 30;
  static const int warningDaysBefore = 3;
  
  static Timestamp calculateExpiry({int days = daysUntilAutoDelete}) {
    return Timestamp.fromDate(
      DateTime.now().add(Duration(days: days))
    );
  }
}