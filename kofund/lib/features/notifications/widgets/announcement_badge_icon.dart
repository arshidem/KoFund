import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import '../providers/announcement_provider.dart';
import 'announcement_bottom_sheet.dart';

class AnnouncementBadgeIcon extends StatelessWidget {
  const AnnouncementBadgeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnnouncementProvider>(
      builder: (context, provider, child) {
        final count = provider.unreadCount;
        
        return badges.Badge(
          showBadge: count > 0,
          position: badges.BadgePosition.topEnd(top: -4, end: -4),
          badgeStyle: badges.BadgeStyle(
            badgeColor: AppColors.error(context),
            padding: const EdgeInsets.all(4),
            elevation: 0,
          ),
          badgeContent: Text(
            count > 9 ? '9+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.campaign_outlined, color: Colors.white),
            onPressed: () {
              HapticHelper.light();
              AnnouncementBottomSheet.show(context);
            },
          ),
        );
      },
    );
  }
}





