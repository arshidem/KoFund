import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'stats_card_skeleton.dart';
import 'program_card_skeleton.dart';
import 'members_skeleton.dart';
import 'history_skeleton.dart';

class DashboardSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const DashboardSkeleton({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        children: [
          // Skeleton App Bar
          _buildSkeletonAppBar(),
          
          // Skeleton Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10.0),
              children: [
                const SizedBox(height: 16),
                StatsCardSkeleton(isDarkMode: isDarkMode),
                const SizedBox(height: 24),
                ProgramCardSkeleton(isDarkMode: isDarkMode),
                const SizedBox(height: 24),
                MembersSkeleton(isDarkMode: isDarkMode),
                const SizedBox(height: 24),
                HistorySkeleton(isDarkMode: isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonAppBar() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 200,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 80,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
