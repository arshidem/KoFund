import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/notification_navigator.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notification = ModalRoute.of(context)!.settings.arguments as AppNotification;
    final provider = context.read<NotificationProvider>();

    // Mark as read when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!notification.isRead) {
        provider.markAsRead(notification.id);
      }
    });

    return GradientSheetScaffold(
      title: 'Notification Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Notification'),
                  content: const Text('Are you sure you want to delete this notification?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.deleteNotification(notification.id);
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: notification.priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    notification.typeIcon,
                    size: 35,
                    color: notification.priorityColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.timeAgo,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      if (notification.senderName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'From: ${notification.senderName!}',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),

            // Body
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                notification.body,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            // Metadata
            if (notification.data.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: notification.data.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                entry.key.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action Button
            if (notification.deepLink != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    NotificationNavigator.handleNotificationTap(
                      context,
                      {
                        'type': notification.type.toString(),
                        'deepLink': notification.deepLink,
                        ...notification.data,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
