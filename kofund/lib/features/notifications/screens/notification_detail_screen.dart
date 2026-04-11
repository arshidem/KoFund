import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/notification_navigator.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/haptic_helper.dart';

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
      title: 'Notification',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          onPressed: () => _confirmDelete(context, provider, notification.id),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Sphere
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: notification.priorityColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.typeIcon,
                  size: 40,
                  color: notification.priorityColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title & Time
            Text(
              notification.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notification.timeAgo,
              style: TextStyle(
                color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Body Text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.textPrimary(context).withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                notification.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, 
                  height: 1.6,
                  color: AppColors.textPrimary(context).withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Refined Details Section
            if (notification.data.isNotEmpty && _hasViewableData(notification.data)) ...[
              const SizedBox(height: 32),
              _buildSectionHeader(context, 'ADDITIONAL INFORMATION'),
              const SizedBox(height: 16),
              _buildRefinedDataCard(context, notification.data),
            ],

            const SizedBox(height: 48),

            // Action Button
            if (notification.deepLink != null || _canTakeAction(notification))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticHelper.medium();
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
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                  ),
                  child: const Text(
                    'View & Respond',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasViewableData(Map<String, dynamic> data) {
    return data.keys.any((key) => !_isInternalKey(key));
  }

  bool _isInternalKey(String key) {
    const internalKeys = {
      'type', 'deepLink', 'click_action', 'targetRole',
      'fcmToken', 'notificationId',
    };
    if (internalKeys.contains(key)) return true;
    // Block any key ending in 'Id' (camelCase) or containing '_id' (snake_case)
    if (key.endsWith('Id') || key.contains('_id')) return true;
    return false;
  }

  bool _canTakeAction(AppNotification notification) {
    return notification.type.toString().contains('pending') || notification.type.toString().contains('request');
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context).withValues(alpha: 0.4),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRefinedDataCard(BuildContext context, Map<String, dynamic> data) {
    final filteredEntries = data.entries.where((e) => !_isInternalKey(e.key)).toList();

    if (filteredEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.05)),
      ),
      child: Column(
        children: filteredEntries.map((entry) {
          final isLast = filteredEntries.last == entry;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        entry.value.toString(),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(color: AppColors.border(context).withValues(alpha: 0.5)),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, NotificationProvider provider, String id) {
    HapticHelper.heavy();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Log?'),
        content: const Text('This notification record will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              provider.deleteNotification(id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
