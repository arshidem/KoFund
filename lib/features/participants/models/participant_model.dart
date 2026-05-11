import 'package:cloud_firestore/cloud_firestore.dart';

class ParticipantModel {
  String participantId;
  String eventId;
  String userId;
  String userName;
  String userEmail;
  String communityId;
  DateTime joinedAt;
  String status; // 'joined', 'cancelled'
  double? contributionPaid; // Amount paid for this event
  bool hasPaidContribution; // Whether user paid the suggested contribution

  ParticipantModel({
    required this.participantId,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.communityId,
    required this.joinedAt,
    this.status = 'joined',
    this.contributionPaid,
    this.hasPaidContribution = false,
  });

  // ✅ ADD THIS: copyWith method
  ParticipantModel copyWith({
    String? participantId,
    String? eventId,
    String? userId,
    String? userName,
    String? userEmail,
    String? communityId,
    DateTime? joinedAt,
    String? status,
    double? contributionPaid,
    bool? hasPaidContribution,
  }) {
    return ParticipantModel(
      participantId: participantId ?? this.participantId,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      communityId: communityId ?? this.communityId,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
      contributionPaid: contributionPaid ?? this.contributionPaid,
      hasPaidContribution: hasPaidContribution ?? this.hasPaidContribution,
    );
  }

  factory ParticipantModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ParticipantModel(
      participantId: documentId,
      eventId: map['eventId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      communityId: map['communityId'] ?? '',
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'joined',
      contributionPaid: (map['contributionPaid'] ?? 0).toDouble(),
      hasPaidContribution: map['hasPaidContribution'] ?? false,
    );
  }
// Add to your ParticipantModel class:

factory ParticipantModel.empty() {
  return ParticipantModel(
    participantId: '',
    eventId: '',
    userId: '',
    userName: '',
    userEmail: '',
    communityId: '',
    contributionPaid: 0,
    hasPaidContribution: false,
    status: 'active',
    joinedAt: DateTime.now(),
  );
}
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'communityId': communityId,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'status': status,
      'contributionPaid': contributionPaid,
      'hasPaidContribution': hasPaidContribution,
    };
  }
}





