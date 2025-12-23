import 'package:cloud_firestore/cloud_firestore.dart';

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
    Timestamp? createdAt,
  }) : 
    status = 'completed',
    createdAt = createdAt ?? Timestamp.now();

  // ✅ UPDATE: Factory constructor with note
  factory ContributionModel.fromMap(Map<String, dynamic> map, String id) {
    return ContributionModel(
      contributionId: id,
      programId: map['programId'] ?? '',
      userId: map['userId'] ?? '',
      communityId: map['communityId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      note: map['note'], // ✅ Add this
      isMonthlyContribution: map['isMonthlyContribution'] ?? false,
      monthId: map['monthId'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  // ✅ UPDATE: toMap method with note
  Map<String, dynamic> toMap() {
    return {
      'programId': programId,
      'userId': userId,
      'communityId': communityId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': 'completed',
      'createdAt': createdAt,
      // ✅ ADD: Note field
      'note': note,
      // ✅ ADD: Monthly fields
      'isMonthlyContribution': isMonthlyContribution,
      'monthId': monthId,
    };
  }

  // ✅ UPDATE: copyWith method with note
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
    Timestamp? createdAt,
  }) {
    return ContributionModel(
      contributionId: contributionId ?? this.contributionId,
      programId: programId ?? this.programId,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note, // ✅ Add this
      isMonthlyContribution: isMonthlyContribution ?? this.isMonthlyContribution,
      monthId: monthId ?? this.monthId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods
  bool get isCompleted => true;
  bool get isPending => false;
  bool get isFailed => false;
  bool get isRefunded => false;
}

class ContributionStatus {
  static const String completed = 'completed';
  static List<String> get all => [completed];
}