import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import '../providers/announcement_provider.dart';

class AnnouncementBottomSheet extends StatelessWidget {
  const AnnouncementBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Consumer<AnnouncementProvider>(
                  builder: (context, provider, _) {
                    if (provider.unreadCount == 0) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () {
                        HapticHelper.medium();
                        provider.markAllAsRead();
                      },
                      child: Text(
                        'Mark all as read',
                        style: TextStyle(color: AppColors.primary(context)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          Flexible(
            child: Consumer<AnnouncementProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final announcements = provider.allAnnouncements;

                if (announcements.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined, size: 48, color: AppColors.textSecondary(context).withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'No announcements yet',
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: announcements.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    final isRead = announcement['isRead'] == true;
                    final date = (announcement['created_at'] != null)
                        ? (announcement['created_at'] as dynamic).toDate()
                        : DateTime.now();

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead
                            ? AppColors.card(context).withValues(alpha: 0.6)
                            : AppColors.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead
                              ? AppColors.border(context).withValues(alpha: 0.5)
                              : AppColors.primary(context).withValues(alpha: 0.3),
                          width: isRead ? 1 : 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.campaign,
                                size: 18,
                                color: isRead
                                    ? AppColors.textTertiary(context)
                                    : AppColors.primary(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  announcement['title'] ?? 'Announcement',
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                    fontSize: 15,
                                    color: isRead
                                        ? AppColors.textSecondary(context)
                                        : AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.error(context),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM d').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            announcement['body'] ?? '',
                            style: TextStyle(
                              color: isRead
                                  ? AppColors.textTertiary(context)
                                  : AppColors.textSecondary(context),
                              height: 1.4,
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticHelper.light();
                                  provider.markAsRead(announcement['id']);
                                },
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(color: AppColors.primary(context).withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  'Mark as Read',
                                  style: TextStyle(fontSize: 12, color: AppColors.primary(context)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AnnouncementBottomSheet(),
    );
  }
}







