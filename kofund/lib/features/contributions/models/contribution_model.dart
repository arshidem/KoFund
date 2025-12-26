import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ContributionModel {
  String contributionId;
  String programId;
  String userId;
  String communityId;
  double amount;
  String paymentMethod;
  String status;
  Timestamp createdAt;
  
  // ✅ ADD: Note field
  String? note;

  // ✅ ADD: Monthly fields
  bool isMonthlyContribution;
  String? monthId;

  // ✅ ADD: Entry tracking fields (who added this record)
  String? addedByUserId;
  String? addedByUserName;
  Timestamp? addedAt;

  // ✅ ADD: Edit tracking fields
  bool isEdited;
  String? lastEditedByUserId;
  String? lastEditedByUserName;
  Timestamp? lastEditedAt;
  String? editReason;
  
  // ✅ ADD: Edit history array to track all changes
  List<Map<String, dynamic>> editHistory;

  ContributionModel({
    required this.contributionId,
    required this.programId,
    required this.userId,
    required this.communityId,
    required this.amount,
    required this.paymentMethod,
    
    // ✅ ADD: Note parameter
    this.note,
    
    // ✅ ADD: Monthly parameters
    this.isMonthlyContribution = false,
    this.monthId,
    
    // ✅ ADD: Entry tracking parameters
    this.addedByUserId,
    this.addedByUserName,
    this.addedAt,
    
    // ✅ ADD: Edit tracking parameters
    this.isEdited = false,
    this.lastEditedByUserId,
    this.lastEditedByUserName,
    this.lastEditedAt,
    this.editReason,
    
    // ✅ ADD: Edit history parameter
    this.editHistory = const [],
    
    Timestamp? createdAt,
  }) : 
    status = 'completed',
    createdAt = createdAt ?? Timestamp.now();

  // ✅ UPDATE: Factory constructor with all new fields including editHistory
  factory ContributionModel.fromMap(Map<String, dynamic> map, String id) {
    // Parse editHistory from Firestore
    final editHistoryData = map['editHistory'];
    List<Map<String, dynamic>> parsedEditHistory = [];
    
    if (editHistoryData is List) {
      for (var item in editHistoryData) {
        if (item is Map<String, dynamic>) {
          parsedEditHistory.add(item);
        }
      }
    }
    
    return ContributionModel(
      contributionId: id,
      programId: map['programId'] ?? '',
      userId: map['userId'] ?? '',
      communityId: map['communityId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      
      // ✅ Note field
      note: map['note'],
      
      // ✅ Monthly fields
      isMonthlyContribution: map['isMonthlyContribution'] ?? false,
      monthId: map['monthId'],
      
      // ✅ Entry tracking fields
      addedByUserId: map['addedByUserId'],
      addedByUserName: map['addedByUserName'],
      addedAt: map['addedAt'],
      
      // ✅ Edit tracking fields
      isEdited: map['isEdited'] ?? false,
      lastEditedByUserId: map['lastEditedByUserId'],
      lastEditedByUserName: map['lastEditedByUserName'],
      lastEditedAt: map['lastEditedAt'],
      editReason: map['editReason'],
      
      // ✅ Edit history
      editHistory: parsedEditHistory,
      
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  // ✅ UPDATE: toMap method with all new fields including editHistory
  Map<String, dynamic> toMap() {
    return {
      'programId': programId,
      'userId': userId,
      'communityId': communityId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': 'completed',
      'createdAt': createdAt,
      
      // ✅ Note field
      'note': note,
      
      // ✅ Monthly fields
      'isMonthlyContribution': isMonthlyContribution,
      'monthId': monthId,
      
      // ✅ Entry tracking fields
      'addedByUserId': addedByUserId,
      'addedByUserName': addedByUserName,
      'addedAt': addedAt,
      
      // ✅ Edit tracking fields
      'isEdited': isEdited,
      'lastEditedByUserId': lastEditedByUserId,
      'lastEditedByUserName': lastEditedByUserName,
      'lastEditedAt': lastEditedAt,
      'editReason': editReason,
      
      // ✅ Edit history
      'editHistory': editHistory,
    };
  }

  // ✅ UPDATE: copyWith method with all new fields
  ContributionModel copyWith({
    String? contributionId,
    String? programId,
    String? userId,
    String? communityId,
    double? amount,
    String? paymentMethod,
    String? note,
    bool? isMonthlyContribution,
    String? monthId,
    
    // ✅ Entry tracking
    String? addedByUserId,
    String? addedByUserName,
    Timestamp? addedAt,
    
    // ✅ Edit tracking
    bool? isEdited,
    String? lastEditedByUserId,
    String? lastEditedByUserName,
    Timestamp? lastEditedAt,
    String? editReason,
    
    // ✅ Edit history
    List<Map<String, dynamic>>? editHistory,
    
    Timestamp? createdAt,
  }) {
    return ContributionModel(
      contributionId: contributionId ?? this.contributionId,
      programId: programId ?? this.programId,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      
      // ✅ Note field
      note: note ?? this.note,
      
      // ✅ Monthly fields
      isMonthlyContribution: isMonthlyContribution ?? this.isMonthlyContribution,
      monthId: monthId ?? this.monthId,
      
      // ✅ Entry tracking
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedByUserName: addedByUserName ?? this.addedByUserName,
      addedAt: addedAt ?? this.addedAt,
      
      // ✅ Edit tracking
      isEdited: isEdited ?? this.isEdited,
      lastEditedByUserId: lastEditedByUserId ?? this.lastEditedByUserId,
      lastEditedByUserName: lastEditedByUserName ?? this.lastEditedByUserName,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      editReason: editReason ?? this.editReason,
      
      // ✅ Edit history
      editHistory: editHistory ?? this.editHistory,
      
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods
  bool get isCompleted => true;
  bool get isPending => false;
  bool get isFailed => false;
  bool get isRefunded => false;

  // ✅ ADD: Get formatted added by info
  String get addedByInfo {
    if (addedByUserName != null && addedByUserName!.isNotEmpty) {
      return 'Added by: $addedByUserName';
    } else if (addedByUserId != null) {
      return 'Added by: Admin';
    }
    return '';
  }

  // ✅ ADD: Get formatted edited info
  String get editedInfo {
    if (!isEdited) return '';
    
    final parts = [];
    if (lastEditedByUserName != null && lastEditedByUserName!.isNotEmpty) {
      parts.add('Edited by: $lastEditedByUserName');
    }
    if (editReason != null && editReason!.isNotEmpty) {
      parts.add('Reason: $editReason');
    }
    return parts.join(' • ');
  }

  // ✅ ADD: Get month display name for monthly contributions
  String get monthDisplayName {
    if (!isMonthlyContribution || monthId == null) return '';
    
    try {
      final parts = monthId!.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        final date = DateTime(int.parse(year), month, 1);
        final monthName = DateFormat('MMM').format(date);
        return '$monthName $year';
      }
    } catch (e) {
      return monthId!;
    }
    return monthId!;
  }

  // ✅ ADD: Method to create a new edit record
  Map<String, dynamic> createEditRecord({
    required String editedByUserId,
    required String editedByUserName,
    required Map<String, Map<String, dynamic>> changes,
    String? reason,
  }) {
    return {
      'editedAt': Timestamp.now(),
      'editedByUserId': editedByUserId,
      'editedByUserName': editedByUserName,
      'changes': changes,
      'reason': reason ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // ✅ ADD: Method to add an edit record to history
  void addEditRecord({
    required String editedByUserId,
    required String editedByUserName,
    required Map<String, Map<String, dynamic>> changes,
    String? reason,
  }) {
    final editRecord = createEditRecord(
      editedByUserId: editedByUserId,
      editedByUserName: editedByUserName,
      changes: changes,
      reason: reason,
    );
    
    editHistory.add(editRecord);
    
    // Update edit tracking fields
    isEdited = true;
    lastEditedByUserId = editedByUserId;
    lastEditedByUserName = editedByUserName;
    lastEditedAt = Timestamp.now();
    editReason = reason ?? editReason;
  }

  // ✅ ADD: Get the latest edit record
  Map<String, dynamic>? get latestEdit {
    if (editHistory.isEmpty) return null;
    
    // Sort by timestamp (newest first)
    editHistory.sort((a, b) {
      final timeA = a['timestamp'] ?? 0;
      final timeB = b['timestamp'] ?? 0;
      return timeB.compareTo(timeA);
    });
    
    return editHistory.first;
  }

  // ✅ ADD: Get readable changes description
  String get changesDescription {
    if (!isEdited || editHistory.isEmpty) return '';
    
    final latest = latestEdit;
    if (latest == null) return '';
    
    final changes = latest['changes'] as Map<String, dynamic>?;
    if (changes == null || changes.isEmpty) return '';
    
    final List<String> changeDescriptions = [];
    
    changes.forEach((field, changeData) {
      final oldValue = changeData['old'];
      final newValue = changeData['new'];
      final fieldName = _getFieldDisplayName(field);
      
      changeDescriptions.add('$fieldName: $oldValue → $newValue');
    });
    
    return changeDescriptions.join(', ');
  }

  // ✅ ADD: Helper method for field display names
  String _getFieldDisplayName(String field) {
    final displayNames = {
      'amount': 'Amount',
      'paymentMethod': 'Payment Method',
      'userId': 'Member',
      'programId': 'Program',
      'note': 'Note',
      'monthId': 'Month',
      'isMonthlyContribution': 'Type',
    };
    
    return displayNames[field] ?? field;
  }

  // ✅ ADD: Get formatted edit history
  List<Map<String, dynamic>> get formattedEditHistory {
    if (editHistory.isEmpty) return [];
    
    // Sort by timestamp (newest first)
    final sortedHistory = List<Map<String, dynamic>>.from(editHistory)
      ..sort((a, b) {
        final timeA = a['timestamp'] ?? 0;
        final timeB = b['timestamp'] ?? 0;
        return timeB.compareTo(timeA);
      });
    
    return sortedHistory;
  }

  // ✅ ADD: Check if this contribution can be edited
  bool canBeEdited() {
    // You can add logic here to restrict edits based on time or other conditions
    // For example, only allow edits within 24 hours
    final now = DateTime.now();
    final createdDate = createdAt.toDate();
    final difference = now.difference(createdDate);
    
    // Allow edits within 30 days (adjust as needed)
    return difference.inDays <= 30;
  }
}

class ContributionStatus {
  static const String completed = 'completed';
  static List<String> get all => [completed];
}