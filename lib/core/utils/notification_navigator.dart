import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routing/route_names.dart';
import '../../features/notifications/models/notification_model.dart';

class NotificationNavigator {
  /// Called from inside the app (e.g. NotificationDetailScreen action button).
  static void handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type']?.toString() ?? '';
    final ddeepLink = data['deepLink'];
    final eventId = data['eventId']?.toString();

    // Use deep link if available
    if (ddeepLink != null && ddeepLink is String && ddeepLink.isNotEmpty) {
      _navigateToDdeepLink(ddeepLink, context);
      return;
    }

    // event announcement with eventId → event Details
    if ((type.contains('announcement') || type.contains('event')) &&
        eventId != null &&
        eventId.isNotEmpty) {
      context.push('${RouteNames.eventDetails}/$eventId');
      return;
    }

    if (type.contains('contribution') || type.contains('reminder')) {
      if (eventId != null && eventId.isNotEmpty) {
        context.push('${RouteNames.eventDetails}/$eventId');
        return;
      }
    }

    if (type.contains('approval')) {
      context.go(RouteNames.communityDashboard);
      return;
    }

    // conversionRequest → stay on notification detail (has Accept/Reject)
    if (type.contains('conversionRequest')) {
      context.go(RouteNames.notifications);
      return;
    }

    if (type.contains('pendingUser') || type.contains('request')) {
      context.push(RouteNames.allMembers);
      return;
    }

    // Default Fallback
    context.go(RouteNames.notifications);
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
      context.push(RouteNames.notificationDetail, extra: notification);
      return;
    }
    handleNotificationTap(context, data);
  }

  static void _navigateToDdeepLink(String ddeepLink, BuildContext context) {
    final segments = ddeepLink.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) {
      context.go(RouteNames.notifications);
      return;
    }

    switch (segments[0]) {
      case 'event':
        if (segments.length > 1) {
          context.push('${RouteNames.eventDetails}/${segments[1]}');
        }
        break;

      case 'contribution':
        if (segments.length > 1) {
          context.go(RouteNames.communityDashboard);
        }
        break;

      case 'profile':
        context.push(RouteNames.profile);
        break;

      default:
        context.go(RouteNames.notifications);
    }
  }
}
