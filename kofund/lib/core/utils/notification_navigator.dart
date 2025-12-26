import 'package:flutter/material.dart';
import '../../routing/route_names.dart';

class NotificationNavigator {
  static void handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type'];
    final id = data['id'];
    final deepLink = data['deepLink'];

    // Use deep link if available
    if (deepLink != null && deepLink is String) {
      _navigateToDeepLink(deepLink, context);
      return;
    }

    // Navigate based on notification type
    switch (type) {
      case 'payment':
      case 'contribution':
        Navigator.pushNamed(
          context,
          RouteNames.communityDashboard,
          arguments: {'contributionId': id},
        );
        break;

      case 'programUpdate':
        Navigator.pushNamed(
          context,
          RouteNames.programDetails,
          arguments: id,
        );
        break;

      case 'adminAlert':
      case 'approval':
        Navigator.pushNamed(
          context,
          RouteNames.approvalRequests,
        );
        break;

      case 'community':
        Navigator.pushNamed(
          context,
          RouteNames.communityDashboard,
        );
        break;

      default:
        Navigator.pushNamed(context, RouteNames.notifications);
    }
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
          Navigator.pushNamed(
            context,
            RouteNames.communityDashboard,
            // arguments: {'contributionId': segments[1]},
          );
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