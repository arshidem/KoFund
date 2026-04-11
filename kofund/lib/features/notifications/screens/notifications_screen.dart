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
          belowHeader: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _buildSearchBarArea(context, provider),
          ),
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async => provider.refresh(),
              ),
              if (_selectedCommunity != null ||
                  _selectedType != null ||
                  _showUnreadOnly)
                _buildActiveFilterChips(provider),
              _buildNotificationList(provider),
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
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
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_none,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    provider.unreadCount > 0 
                      ? '${provider.unreadCount} New notifications'
                      : 'No new notifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _showFilterDialog(context),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 18),
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
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: List.generate(
              6, 
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: NotificationSkeleton(),
              ),
            ),
          ),
        ),
      );
    }

    if (provider.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load your notifications',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => provider.refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Try Again'),
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
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: AppColors.primary(context).withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _selectedCommunity != null 
                    ? 'No notifications here' 
                    : 'All caught up!',
                style: TextStyle(
                  fontSize: 20, 
                  color: AppColors.textPrimary(context), 
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _selectedCommunity != null 
                      ? 'No updates for the selected community yet.' 
                      : 'We\'ll notify you when something important happens.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Grouping notifications
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<AppNotification>> grouped = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (var n in provider.notifications) {
      final date = DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
      if (date == today) {
        grouped['Today']!.add(n);
      } else if (date == yesterday) {
        grouped['Yesterday']!.add(n);
      } else {
        grouped['Earlier']!.add(n);
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          int count = 0;
          for (var entry in grouped.entries) {
            if (entry.value.isEmpty) continue;
            
            // Header
            if (index == count) {
              return _buildGroupHeader(entry.key);
            }
            count++;
            
            // Items
            if (index < count + entry.value.length) {
              final n = entry.value[index - count];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: NotificationCard(notification: n),
              );
            }
            count += entry.value.length;
          }
          return null;
        },
        childCount: grouped.values.expand((x) => x).length + 
                  grouped.values.where((x) => x.isNotEmpty).length,
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary(context).withValues(alpha: 0.6),
          letterSpacing: 1.2,
        ),
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
                            label: Text('${community.substring(0, 8)}...'),
                            selected: _selectedCommunity == community,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCommunity = community;
                              });
                              provider.filterByCommunity(community);
                              Navigator.pop(context);
                            },
                          );
                        }),
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
                      }),
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

class NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const NotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Modern colors for different types
    Color getBgColor() {
      switch (notification.type) {
        case NotificationType.payment:
        case NotificationType.contribution:
          return Colors.green;
        case NotificationType.withdrawal:
          return Colors.red;
        case NotificationType.approval:
          return Colors.blue;
        case NotificationType.reminder:
          return Colors.orange;
        case NotificationType.pendingUser:
          return Colors.orangeAccent;
        default:
          return AppColors.primary(context);
      }
    }

    final accentColor = getBgColor();

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => provider.deleteNotification(notification.id),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: !notification.isRead 
              ? accentColor.withValues(alpha: 0.3) 
              : AppColors.border(context).withValues(alpha: 0.5),
            width: !notification.isRead ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
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
            child: Stack(
              children: [
                // Activity indicator for unread
                if (!notification.isRead)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(color: accentColor),
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Icon Container
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          notification.typeIcon,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.textPrimary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(context),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Footer Metadata
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary(context).withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  notification.timeAgo,
                                  style: TextStyle(
                                    fontSize: 11, 
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary(context).withValues(alpha: 0.6),
                                  ),
                                ),
                                if (notification.senderName != null) ...[
                                  const SizedBox(width: 12),
                                  Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.textSecondary(context).withValues(alpha:0.3), shape: BoxShape.circle)),
                                  const SizedBox(width: 12),
                                  Text(
                                    notification.senderName!,
                                    style: TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary(context).withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(height: 14, width: 120, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(height: 10, width: 200, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

