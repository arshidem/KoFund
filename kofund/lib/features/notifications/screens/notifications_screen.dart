import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/notification_types.dart';
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _selectedCommunity;
  NotificationType? _selectedType;
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return GradientSheetScaffold(
          title: 'Notifications',
          automaticallyImplyLeading: Navigator.canPop(context),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: AppDimensions.screenPaddingHorizontal),
              child: _buildNotificationOverflowMenu(context, provider),
            ),
          ],
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: _buildSearchBarArea(context, provider),
                ),
              ),
              CupertinoSliverRefreshControl(
                onRefresh: () async => provider.refresh(),
              ),
              if (_selectedCommunity != null ||
                  _selectedType != null ||
                  _showUnreadOnly)
                _buildActiveFilterChips(provider),
              _buildNotificationList(provider),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(color: AppColors.background(context)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationOverflowMenu(
    BuildContext context,
    NotificationProvider provider,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'mark_all_read',
          child: Row(
            children: [
              Icon(Icons.mark_email_read, size: 20),
              SizedBox(width: 8),
              Text('Mark all as read'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'clear_all',
          child: Row(
            children: [
              Icon(Icons.delete_sweep, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Clear all', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'clear_filters',
          child: Row(
            children: [
              Icon(Icons.filter_alt_off, size: 20),
              SizedBox(width: 8),
              Text('Clear filters'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'mark_all_read') {
          provider.markAllAsRead();
        } else if (value == 'clear_all') {
          _showClearAllDialog(context, provider);
        } else if (value == 'clear_filters') {
          _clearFilters(provider);
        }
      },
    );
  }

  Widget _buildSearchBarArea(BuildContext context, NotificationProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_none,
                  color: AppColors.textSecondary(context),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${provider.unreadCount} unread notifications',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _showFilterDialog(context),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Icon(Icons.tune, color: AppColors.primary(context), size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChips(NotificationProvider provider) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        color: AppColors.background(context),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_selectedCommunity != null)
                _buildFilterChip('Community: $_selectedCommunity', () {
                  setState(() => _selectedCommunity = null);
                  provider.filterByCommunity(null);
                }),
              if (_selectedType != null)
                _buildFilterChip('Type: ${_selectedType!.name}', () {
                  setState(() => _selectedType = null);
                  provider.filterByType(null);
                }),
              if (_showUnreadOnly)
                _buildFilterChip('Unread only', () {
                  setState(() => _showUnreadOnly = false);
                  provider.toggleUnreadFilter();
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(context),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDeleted,
            child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(NotificationProvider provider) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load notifications', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => provider.refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none,
                size: 80,
                color: _selectedCommunity != null ? Colors.orange : Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedCommunity != null ? 'No notifications for this community' : 'No notifications yet',
                style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final notification = provider.notifications[index];
          return NotificationTile(notification: notification);
        },
        childCount: provider.notifications.length,
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Notifications'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Community filter
                  const Text('Community:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (provider.userCommunities.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _selectedCommunity == null,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCommunity = null;
                            });
                            provider.filterByCommunity(null);
                            Navigator.pop(context);
                          },
                        ),
                        ...provider.userCommunities.map((community) {
                          return FilterChip(
                            label: Text(community.substring(0, 8) + '...'),
                            selected: _selectedCommunity == community,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCommunity = community;
                              });
                              provider.filterByCommunity(community);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Type filter
                  const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedType == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = null;
                          });
                          provider.filterByType(null);
                          Navigator.pop(context);
                        },
                      ),
                      ...NotificationType.values.map((type) {
                        return FilterChip(
                          label: Text(type.name),
                          selected: _selectedType == type,
                          onSelected: (selected) {
                            setState(() {
                              _selectedType = type;
                            });
                            provider.filterByType(type);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Unread filter
                  Row(
                    children: [
                      Checkbox(
                        value: _showUnreadOnly,
                        onChanged: (value) {
                          setState(() {
                            _showUnreadOnly = value ?? false;
                          });
                          if (value == true) {
                            provider.toggleUnreadFilter();
                          }
                          Navigator.pop(context);
                        },
                      ),
                      const Text('Show unread only'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _clearFilters(provider);
                  Navigator.pop(context);
                },
                child: const Text('Clear all'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _clearFilters(NotificationProvider provider) {
    setState(() {
      _selectedCommunity = null;
      _selectedType = null;
      _showUnreadOnly = false;
    });
    provider.clearFilters();
  }

  void _showClearAllDialog(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will remove all notifications. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const NotificationTile({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => provider.deleteNotification(notification.id),
      child: ListTile(
        onTap: () {
          if (!notification.isRead) {
            provider.markAsRead(notification.id);
          }
          Navigator.pushNamed(
            context,
            RouteNames.notificationDetail,
            arguments: notification,
          );
        },
        onLongPress: () {
          _showDebugInfo(context, notification);
        },
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: notification.priorityColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            notification.typeIcon,
            color: notification.priorityColor,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (notification.communityId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  notification.communityId!.substring(0, 6) + '...',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            if (kDebugMode)
              Text(
                '#${notification.id.substring(0, 6)}...',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  notification.timeAgo,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (notification.senderName != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notification.senderName!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            if (kDebugMode && notification.userId != null)
              Text(
                'User: ${notification.userId!.substring(0, 8)}...',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!notification.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDebugInfo(BuildContext context, AppNotification notification) {
    if (!kDebugMode) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${notification.id}'),
              const SizedBox(height: 8),
              Text('Title: ${notification.title}'),
              const SizedBox(height: 8),
              Text('Body: ${notification.body}'),
              const SizedBox(height: 8),
              Text('Type: ${notification.type.name}'),
              const SizedBox(height: 8),
              Text('User ID: ${notification.userId ?? "null"}'),
              const SizedBox(height: 8),
              Text('Community ID: ${notification.communityId ?? "null"}'),
              const SizedBox(height: 8),
              Text('Is Read: ${notification.isRead}'),
              const SizedBox(height: 8),
              Text('Timestamp: ${notification.timestamp}'),
              const SizedBox(height: 8),
              Text('Priority: ${notification.priority.name}'),
              const SizedBox(height: 8),
              Text('Data: ${notification.data}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

