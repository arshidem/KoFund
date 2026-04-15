import 'package:flutter/material.dart';
import '../../routing/route_names.dart';
import '../../features/notifications/models/notification_model.dart';

class NotificationNavigator {
  /// Called from inside the app (e.g. NotificationDetailScreen action button).
  static void handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type']?.toString() ?? '';
    final deepLink = data['deepLink'];
    final programId = data['programId']?.toString();

    // Use deep link if available
    if (deepLink != null && deepLink is String && deepLink.isNotEmpty) {
      _navigateToDeepLink(deepLink, context);
      return;
    }

    // Program announcement with programId → Program Details
    if ((type.contains('announcement') || type.contains('program')) &&
        programId != null &&
        programId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        RouteNames.programDetails,
        arguments: programId,
      );
      return;
    }

    if (type.contains('contribution') || type.contains('reminder')) {
      if (programId != null && programId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          RouteNames.programDetails,
          arguments: programId,
        );
        return;
      }
    }

    if (type.contains('approval')) {
      Navigator.pushNamed(context, RouteNames.communityDashboard);
      return;
    }

    if (type.contains('pendingUser') || type.contains('request')) {
      Navigator.pushNamed(context, RouteNames.approvalRequests);
      return;
    }

    // Default Fallback
    Navigator.pushNamed(context, RouteNames.notifications);
  }

  /// Called from FCM tap (cold / background start).
  /// Opens the NotificationDetailScreen if we have a full notification object,
  /// otherwise falls back to handleNotificationTap.
  static void handleFCMTap(
    BuildContext context,
    Map<String, dynamic> data, {
    AppNotification? notification,
  }) {
    if (notification != null) {
      Navigator.pushNamed(
        context,
        RouteNames.notificationDetail,
        arguments: notification,
      );
      return;
    }
    handleNotificationTap(context, data);
  }

  static void _navigateToDeepLink(String deepLink, BuildContext context) {
    final segments = deepLink.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) {
      Navigator.pushNamed(context, RouteNames.notifications);
      return;
    }

    switch (segments[0]) {
      case 'program':
        if (segments.length > 1) {
          Navigator.pushNamed(
            context,
            RouteNames.programDetails,
            arguments: segments[1],
          );
        }
        break;

      case 'contribution':
        if (segments.length > 1) {
          Navigator.pushNamed(context, RouteNames.communityDashboard);
        }
        break;

      case 'profile':
        Navigator.pushNamed(context, RouteNames.profile);
        break;

      default:
        Navigator.pushNamed(context, RouteNames.notifications);
    }
  }
}
