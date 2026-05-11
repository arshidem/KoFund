import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/routing/route_names.dart';

class NotificationBadge extends StatelessWidget {
  final Color? badgeColor;
  final Color? textColor;
  final double iconSize;
  final bool showBadge;

  const NotificationBadge({
    super.key,
    this.badgeColor,
    this.textColor,
    this.iconSize = 24,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                size: iconSize,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.pushNamed(context, RouteNames.notifications);
              },
            ),
            if (showBadge && unreadCount > 0) ...[
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}





