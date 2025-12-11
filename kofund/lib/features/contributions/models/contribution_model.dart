import 'package:cloud_firestore/cloud_firestore.dart';

class ContributionModel {
  String contributionId;
  String programId;
  String userId;
  String communityId;
  double amount;
  String paymentMethod; // cash, online, etc.
  String status; // Always 'completed'
  Timestamp createdAt;

  ContributionModel({
    required this.contributionId,
    required this.programId,
    required this.userId,
    required this.communityId,
    required this.amount,
    required this.paymentMethod,
    Timestamp? createdAt,
  }) : 
    status = 'completed', // 🆕 ALWAYS SET TO COMPLETED
    createdAt = createdAt ?? Timestamp.now();

  // 🆕 SIMPLIFIED CONSTRUCTOR - status is always 'completed'
  ContributionModel.completed({
    required this.contributionId,
    required this.programId,
    required this.userId,
    required this.communityId,
    required this.amount,
    required this.paymentMethod,
    Timestamp? createdAt,
  }) : 
    status = 'completed',
    createdAt = createdAt ?? Timestamp.now();

  factory ContributionModel.fromMap(Map<String, dynamic> map, String id) {
    return ContributionModel(
      contributionId: id,
      programId: map['programId'] ?? '',
      userId: map['userId'] ?? '',
      communityId: map['communityId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'programId': programId,
      'userId': userId,
      'communityId': communityId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': 'completed', // 🆕 ALWAYS 'completed'
      'createdAt': createdAt,
    };
  }

  // 🆕 SIMPLIFIED HELPER METHODS
  bool get isCompleted => true; // Always true
  bool get isPending => false; // Always false
  bool get isFailed => false; // Always false
  bool get isRefunded => false; // Always false

  // 🆕 COPY WITH METHOD (status remains 'completed')
  ContributionModel copyWith({
    String? contributionId,
    String? programId,
    String? userId,
    String? communityId,
    double? amount,
    String? paymentMethod,
    Timestamp? createdAt,
  }) {
    return ContributionModel(
      contributionId: contributionId ?? this.contributionId,
      programId: programId ?? this.programId,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// 🆕 SIMPLIFIED STATUS CONSTANTS (only completed matters)
class ContributionStatus {
  static const String completed = 'completed';
  
  static List<String> get all => [completed]; // Only completed status
}