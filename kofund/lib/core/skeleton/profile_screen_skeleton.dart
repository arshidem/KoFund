// lib/features/profile/skeleton/profile_screen_skeleton.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_colors.dart';

class ProfileScreenSkeleton extends StatelessWidget {
  final bool isDarkMode;
  final bool showBackButton;

  const ProfileScreenSkeleton({
    super.key,
    required this.isDarkMode,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = isDarkMode ? const Color(0xFF1A2423) : Colors.grey[300]!;
    final Color highlightColor = isDarkMode ? const Color(0xFF2A3433) : Colors.grey[100]!;
    final Color backgroundColor = isDarkMode ? const Color(0xFF0F1716) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            // Dummy AppBar (Matches ProfileScreen expandedHeight)
            SliverAppBar(
              expandedHeight: 340,
              backgroundColor: backgroundColor,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Avatar Skeleton
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? const Color(0xFF1A2423) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Profile Info Skeleton
                    _buildInfoSkeleton(isDarkMode),
                    const SizedBox(height: 30), // Match bottom margin
                  ],
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Stats Skeleton
                    _buildStatsSkeleton(isDarkMode),
                    const SizedBox(height: 32),
                    
                    // Control Center Skeleton
                    _buildControlCenterSkeleton(isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSkeleton(bool isDark) {
    return Column(
      children: [
        Container(
          width: 200,
          height: 28,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 150,
          height: 14,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 100,
          height: 24,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSkeleton(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildStatCardSkeleton(isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCardSkeleton(isDark)),
      ],
    );
  }

  Widget _buildStatCardSkeleton(bool isDark) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildControlCenterSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 12,
          margin: const EdgeInsets.only(left: 4, bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ],
    );
  }
}
