import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/notification_Types.dart';

class NotificationChannels {
  static const Map<String, Map<String, String>> _channels = {
    'payments_channel': {
      'name': 'Payments',
      'description': 'Payment notifications and updates',
    },
    'events_channel': {
      'name': 'events',
      'description': 'event updates and announcements',
    },
    'new_events_channel': { // 🆕 ADDED
      'name': 'New events',
      'description': 'Notifications when new events are created',
    },
    'admin_channel': {
      'name': 'Admin Alerts',
      'description': 'Important alerts for administrators',
    },
    'system_channel': {
      'name': 'System',
      'description': 'System updates and maintenance',
    },
    'announcements_channel': {
      'name': 'Announcements',
      'description': 'General announcements',
    },
    'reminders_channel': {
      'name': 'Reminders',
      'description': 'Payment reminders and deadlines',
    },
    'approvals_channel': {
      'name': 'Approvals',
      'description': 'Account and request approvals',
    },
    'withdrawals_channel': {
      'name': 'Withdrawals',
      'description': 'Withdrawal updates',
    },
    'account_channel': {
      'name': 'Account',
      'description': 'Account security and updates',
    },
    'community_channel': {
      'name': 'Community',
      'description': 'Community news and updates',
    },
    'contributions_channel': {
      'name': 'Contributions',
      'description': 'Contribution updates',
    },
    'default_channel': {
      'name': 'General',
      'description': 'Other notifications',
    },
  };

  static String getChannelId(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return 'payments_channel';
      case NotificationType.update:
        return 'events_channel';
      case NotificationType.event: // 🆕 ADDED
        return 'new_events_channel';
      case NotificationType.adminAlert:
        return 'admin_channel';
      case NotificationType.system:
        return 'system_channel';
      case NotificationType.announcement:
        return 'announcements_channel';
      case NotificationType.reminder:
        return 'reminders_channel';
      case NotificationType.approval:
        return 'approvals_channel';
      case NotificationType.withdrawal:
        return 'withdrawals_channel';
      case NotificationType.account:
        return 'account_channel';
      case NotificationType.community:
        return 'community_channel';
      case NotificationType.contribution:
        return 'contributions_channel';
      case NotificationType.pendingUser:
        return 'admin_channel';
      case NotificationType.conversionRequest:
        return 'approvals_channel';
      default:
        return 'default_channel';
    }
  }

  static String getChannelName(NotificationType type) {
    final channelId = getChannelId(type);
    return _channels[channelId]?['name'] ?? 'General';
  }

  static Future<void> createAllChannels(
    FlutterLocalNotificationsPlugin notificationsPlugin,
  ) async {
    final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      for (final entry in _channels.entries) {
        final channel = AndroidNotificationChannel(
          entry.key,
          entry.value['name']!,
          description: entry.value['description'],
          importance: Importance.high,
          showBadge: true,
          enableLights: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }
}





