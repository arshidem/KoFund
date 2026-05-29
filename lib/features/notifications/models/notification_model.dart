import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/notification_Types.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final Map<String, dynamic> data;
  final String? userId;
  final String? eventId;
  final String? communityId;
  final String? communityName; // 🆕 ADD THIS FIELD
  final bool isRead;
  final DateTime timestamp;
  final String? deepLink;
  final String? senderName;
  final String? imageUrl;

  AppNotification({
    required this.id, // ✅ MADE REQUIRED
    required this.eventId,
    required this.title,
    required this.body,
    required this.type,
    this.priority = NotificationPriority.normal,
    this.data = const {},
    this.userId,
    this.communityId,
    this.communityName,
    this.isRead = false,
    required this.timestamp,
    this.deepLink,
    this.senderName,
    this.imageUrl,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: _stringToNotificationType(data['type']),
      priority: _stringToPriority(data['priority']),
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      userId: data['userId'],
      eventId: data['eventId'],
      communityId: data['communityId'],
      communityName: data['communityName'], // 🆕 ADD THIS
      isRead: data['isRead'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      deepLink: data['deepLink'],
      senderName: data['senderName'],
      imageUrl: data['imageUrl'],
    );
  }

  static NotificationType _stringToNotificationType(String? type) {
    if (type == null) return NotificationType.announcement;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == type.toLowerCase(),
      );
    } catch (_) {
      return NotificationType.announcement;
    }
  }

  static NotificationPriority _stringToPriority(String? priority) {
    if (priority == null) return NotificationPriority.normal;
    try {
      return NotificationPriority.values.firstWhere(
        (e) => e.toString().split('.').last == priority.toLowerCase(),
      );
    } catch (_) {
      return NotificationPriority.normal;
    }
  }

  Map<String, dynamic> toFirestore() {
    debugPrint("📝 toFirestore() - data field type: ${data.runtimeType}");
    debugPrint("📝 toFirestore() - data content: $data");
    
    return {
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'data': data, // This should be Map<String, dynamic>
      'userId': userId,
      'eventId': eventId,
      'communityId': communityId,
      'communityName': communityName, // 🆕 ADD THIS
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'deepLink': deepLink,
      'senderName': senderName,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Copy with method for updates
  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    Map<String, dynamic>? data,
    String? userId,
    String? eventId,
    String? communityId,
    String? communityName, // 🆕 ADD THIS
    bool? isRead,
    DateTime? timestamp,
    String? deepLink,
    String? senderName,
    String? imageUrl,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      data: data ?? this.data,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      communityId: communityId ?? this.communityId,
      communityName: communityName ?? this.communityName, // 🆕 ADD THIS
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      deepLink: deepLink ?? this.deepLink,
      senderName: senderName ?? this.senderName,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  // UI Helpers
  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.critical:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.normal:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.grey;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.update:
        return Icons.update;
      case NotificationType.event: // 🆕 ADDED THIS CASE
        return Icons.calendar_today;
      case NotificationType.adminAlert:
        return Icons.admin_panel_settings;
      case NotificationType.system:
        return Icons.warning;
      case NotificationType.announcement:
        return Icons.announcement;
      case NotificationType.reminder:
        return Icons.notifications_active;
      case NotificationType.approval:
        return Icons.check_circle;
      case NotificationType.withdrawal:
        return Icons.money_off;
      case NotificationType.account:
        return Icons.person;
      case NotificationType.community:
        return Icons.groups;
      case NotificationType.contribution:
        return Icons.currency_rupee;
      case NotificationType.pendingUser:
        return Icons.person_add;
      case NotificationType.conversionRequest:
        return Icons.merge_type_rounded;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  bool get isHighPriority => 
      priority == NotificationPriority.critical || 
      priority == NotificationPriority.high;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}





