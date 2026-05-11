// lib/features/issues/models/issue_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class IssueModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final String? stepsToReproduce;
  final String? screenshotUrl;
  final String reporterId;
  final String reporterEmail;
  final String reporterName;
  final String status;
  final String? assignedDeveloperId;
  final String? assignedDeveloperName;
  final String? resolutionNotes;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String appVersion;
  final String platform;

  IssueModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.stepsToReproduce,
    this.screenshotUrl,
    required this.reporterId,
    required this.reporterEmail,
    required this.reporterName,
    this.status = 'pending',
    this.assignedDeveloperId,
    this.assignedDeveloperName,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.appVersion,
    required this.platform,
  });

  // ✅ COPYWITH METHOD
  IssueModel copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? stepsToReproduce,
    String? screenshotUrl,
    String? reporterId,
    String? reporterEmail,
    String? reporterName,
    String? status,
    String? assignedDeveloperId,
    String? assignedDeveloperName,
    String? resolutionNotes,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? appVersion,
    String? platform,
  }) {
    return IssueModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      stepsToReproduce: stepsToReproduce ?? this.stepsToReproduce,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      reporterId: reporterId ?? this.reporterId,
      reporterEmail: reporterEmail ?? this.reporterEmail,
      reporterName: reporterName ?? this.reporterName,
      status: status ?? this.status,
      assignedDeveloperId: assignedDeveloperId ?? this.assignedDeveloperId,
      assignedDeveloperName: assignedDeveloperName ?? this.assignedDeveloperName,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
    );
  }

  // ✅ HELPER METHODS
  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in-progress';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';
  bool get isAssigned => assignedDeveloperId != null;
  bool get canBeAssigned => isPending;
  Duration get age => DateTime.now().difference(createdAt.toDate());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'stepsToReproduce': stepsToReproduce,
      'screenshotUrl': screenshotUrl,
      'reporterId': reporterId,
      'reporterEmail': reporterEmail,
      'reporterName': reporterName,
      'status': status,
      'assignedDeveloperId': assignedDeveloperId,
      'assignedDeveloperName': assignedDeveloperName,
      'resolutionNotes': resolutionNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'appVersion': appVersion,
      'platform': platform,
    };
  }

  factory IssueModel.fromMap(Map<String, dynamic> map) {
    Timestamp? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
      if (value is Map) {
        try {
          final seconds = value['_seconds'] as int?;
          final nanoseconds = value['_nanoseconds'] as int?;
          if (seconds != null) return Timestamp(seconds, nanoseconds ?? 0);
        } catch (_) {}
      }
      return null;
    }

    return IssueModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      type: map['type']?.toString() ?? 'bug',
      stepsToReproduce: map['stepsToReproduce']?.toString(),
      screenshotUrl: map['screenshotUrl']?.toString(),
      reporterId: map['reporterId']?.toString() ?? '',
      reporterEmail: map['reporterEmail']?.toString() ?? '',
      reporterName: map['reporterName']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      assignedDeveloperId: map['assignedDeveloperId']?.toString(),
      assignedDeveloperName: map['assignedDeveloperName']?.toString(),
      resolutionNotes: map['resolutionNotes']?.toString(),
      createdAt: parseTimestamp(map['createdAt']) ?? Timestamp.now(),
      updatedAt: parseTimestamp(map['updatedAt']) ?? Timestamp.now(),
      appVersion: map['appVersion']?.toString() ?? '1.0.0',
      platform: map['platform']?.toString() ?? 'android',
    );
  }
}





