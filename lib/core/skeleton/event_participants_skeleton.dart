// lib/features/events/skeletons/event_participants_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_colors.dart';

class EventParticipantsSkeleton extends StatelessWidget {
  final bool? isDarkMode;
  final bool isMonthlyy;

  const EventParticipantsSkeleton({
    super.key,
    this.isDarkMode,
    this.isMonthlyy = false,
  });

  Widget _line(BuildContext context, {double width = double.infinity, double height = 12, BorderRadius? radius}) {
    final bool dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? Colors.grey[700] : Colors.white,
        borderRadius: radius ?? BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStatsSkeleton(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2E2E), Color(0xFF0D1B1A)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00C6A2), Color(0xFF00E3C3)],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: dark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: dark 
                  ? Colors.black.withValues(alpha: 0.3) 
                  : const Color(0xFF00C6A2).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _line(context, width: 140, height: 11),
                Container(
                  width: 40,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _line(context, width: 140, height: 36),
            const SizedBox(height: 8),
            _line(context, width: 100, height: 13),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildStatChipSkeleton(context)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatChipSkeleton(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChipSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              _line(context, width: 30, height: 9),
            ],
          ),
          const SizedBox(height: 6),
          _line(context, width: 40, height: 16),
        ],
      ),
    );
  }

  Widget _buildSearchBarSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8, top: 4, left: 16, right: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(100), // radiusFull
                border: Border.all(
                  color: AppColors.border(context).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  _line(context, width: 150, height: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.border(context).withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Center(
              child: Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantItemSkeleton(BuildContext context, bool dark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44, // Gradient avatar size
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(context, width: 140, height: 16, radius: BorderRadius.circular(4)),
                    const SizedBox(height: 6),
                    _line(context, width: 100, height: 12, radius: BorderRadius.circular(4)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _line(context, width: 60, height: 18, radius: BorderRadius.circular(4)),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.border(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    
    final baseColor = dark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = dark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          _buildStatsSkeleton(context, dark),
          _buildSearchBarSkeleton(context),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              itemBuilder: (context, index) => _buildParticipantItemSkeleton(context, dark),
            ),
          ),
        ],
      ),
    );
  }
}





