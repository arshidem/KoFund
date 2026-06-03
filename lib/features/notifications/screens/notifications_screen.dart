import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/notification_Types.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/dialog_helper.dart';
import 'package:go_router/go_router.dart';
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
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 20),
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
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary(context), size: 22),
        padding: EdgeInsets.zero,
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'mark_all_read',
            child: Row(
              children: [
                Icon(Icons.mark_chat_read_outlined, size: 18),
                SizedBox(width: 12),
                Text('Mark all as read', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'clear_all',
            child: Row(
              children: [
                Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                SizedBox(width: 12),
                Text('Clear all notifications', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
              ],
            ),
          ),
          // const PopupMenuDivider(),
          // const PopupMenuItem(
          //   value: 'settings',
          //   child: Row(
          //     children: [
          //       Icon(Icons.settings_outlined, size: 18),
          //       SizedBox(width: 12),
          //       Text('Notification Settings', style: TextStyle(fontSize: 14)),
          //     ],
          //   ),
          // ),
        ],
        onSelected: (value) {
          if (value == 'mark_all_read') {
            provider.markAllAsRead();
          } else if (value == 'clear_all') {
            _showClearAllDialog(context, provider);
          } else if (value == 'settings') {
            // Add navigation to settings if available
            context.push('/notification-settings');
          }
        },
      ),
    );
  }

  Widget _buildSearchBarArea(BuildContext context, NotificationProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.textPrimary(context).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.textPrimary(context).withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_none,
                  color: AppColors.textPrimary(context).withValues(alpha: 0.7),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    provider.unreadCount > 0 
                      ? '${provider.unreadCount} New notifications'
                      : 'No new notifications',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
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
          color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.textPrimary(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _showFilterBottomSheet(context),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.textPrimary(context).withValues(alpha: 0.1)),
              ),
              child: Icon(Icons.tune_rounded, color: AppColors.textPrimary(context), size: 20),
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
                _buildFilterChip('type: ${_selectedType!.name}', () {
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

    // Build a flat list of items: group headers + notifications interleaved
    final List<_NotifListItem> items = [];
    for (var entry in grouped.entries) {
      if (entry.value.isEmpty) continue;
      items.add(_NotifListItem.header(entry.key));
      for (final n in entry.value) {
        items.add(_NotifListItem.notification(n));
      }
    }

    // Collect only notification items for the separator builder so dividers
    // appear only between sibling notification rows (not after a header).
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) {
        final current = items[index];
        final next = items[index + 1];
        // Only show divider between two notification rows
        if (current.isNotification && next.isNotification) {
          return Divider(
            height: 1,
            indent: 0,
            endIndent: 0,
            color: AppColors.textSecondary(context).withValues(alpha: 0.1),
          );
        }
        return const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) return _buildGroupHeader(item.label!);
        return NotificationCard(notification: item.notification!);
      },
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary(context).withValues(alpha: 0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildFilterColumn(String title, List<Widget> children) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...children,
                  ],
                ),
              );
            }

            Widget buildFilterItem(String label, IconData icon, bool isSelected, VoidCallback onTap) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary(context).withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary(context).withValues(alpha: 0.2) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected ? AppColors.primary(context) : AppColors.textSecondary(context).withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _selectedCommunity = null;
                            _selectedType = null;
                            _showUnreadOnly = false;
                          });
                          provider.clearFilters();
                          setState(() {});
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // View Column
                      buildFilterColumn(
                        'VIEW',
                        [
                          buildFilterItem('Show All', Icons.notifications_outlined, !_showUnreadOnly, () {
                            setSheetState(() => _showUnreadOnly = false);
                            if (_showUnreadOnly) provider.toggleUnreadFilter();
                            setState(() {});
                          }),
                          buildFilterItem('Unread Only', Icons.mark_chat_unread_outlined, _showUnreadOnly, () {
                            setSheetState(() => _showUnreadOnly = true);
                            if (!_showUnreadOnly) provider.toggleUnreadFilter();
                            setState(() {});
                          }),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // type Column
                      buildFilterColumn(
                        'TYPE',
                        [
                          buildFilterItem('All TeventTypes', Icons.category_outlined, _selectedType == null, () {
                            setSheetState(() => _selectedType = null);
                            provider.filterByType(null);
                            setState(() {});
                          }),
                          ...NotificationType.values.take(3).map((type) => buildFilterItem(
                            type.name.substring(0, 1).toUpperCase() + type.name.substring(1),
                            Icons.label_important_outline_rounded,
                            _selectedType == type,
                            () {
                              setSheetState(() => _selectedType = type);
                              provider.filterByType(type);
                              setState(() {});
                            },
                          )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

  void _showClearAllDialog(BuildContext context, NotificationProvider provider) async {
    final confirm = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Clear All Notifications',
      message: 'This will remove all notifications. This action cannot be undone.',
      confirmLabel: 'Clear All',
      icon: Icons.delete_sweep_rounded,
      isDestructive: true,
    );

    if (confirm == true) {
      provider.clearAll();
    }
  }
}

// ─── Helper: discriminates list rows for SliverList.separated ───────────────
class _NotifListItem {
  final bool isHeader;
  final String? label;
  final AppNotification? notification;

  const _NotifListItem.header(String l)
      : isHeader = true,
        label = l,
        notification = null;

  const _NotifListItem.notification(AppNotification n)
      : isHeader = false,
        label = null,
        notification = n;

  bool get isNotification => !isHeader;
}

// ─── Notification row – mirrors _buildMemberTile in all_members_screen ───────
class NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const NotificationCard({super.key, required this.notification});

  Color _accentColor(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final accentColor = _accentColor(context);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent.withValues(alpha: 0.15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      onDismissed: (_) => provider.deleteNotification(notification.id),
      child: Material(
        color: isUnread
            ? accentColor.withValues(alpha: 0.04)
            : AppColors.background(context),
        child: InkWell(
          onTap: () {
            if (isUnread) provider.markAsRead(notification.id);
            NotificationService().handleNotificationTap(notification);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Leading icon (CircleAvatar style) ──────────────────
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: accentColor.withValues(alpha: 0.12),
                      child: Icon(
                        notification.typeIcon,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    if (isUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background(context),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // ── Content ────────────────────────────────────────────
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
                                fontWeight:
                                    isUnread ? FontWeight.w700 : FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary(context),
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notification.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(context)
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(context)
                              .withValues(alpha: 0.85),
                          height: 1.35,
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
    final baseColor =
        isDark ? Colors.grey[800]!.withValues(alpha: 0.5) : Colors.grey[200]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circle avatar placeholder
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: baseColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                        height: 12,
                        width: 130,
                        decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(6))),
                    Container(
                        height: 10,
                        width: 36,
                        decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4))),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 5),
                Container(
                    height: 10,
                    width: 180,
                    decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4))),
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
              Text('Ttitle: ${notification.title}'),
              const SizedBox(height: 8),
              Text('Body: ${notification.body}'),
              const SizedBox(height: 8),
              Text('type: ${notification.type.name}'),
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






