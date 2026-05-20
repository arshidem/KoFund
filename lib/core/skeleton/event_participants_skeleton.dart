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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
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
            blurRadius: 20,
            offset: const Offset(0, 10),
            color: dark 
                ? Colors.black.withValues(alpha: 0.3) 
                : const Color(0xFF00C6A2).withValues(alpha: 0.25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(context, width: 120, height: 12),
                  if (isMonthlyy) ...[
                    const SizedBox(height: 4),
                    _line(context, width: 100, height: 14),
                  ],
                ],
              ),
              Container(
                width: 40,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Amount
          _line(context, width: 140, height: 34),
          const SizedBox(height: 8),
          _line(context, width: 100, height: 12),
          
          const SizedBox(height: 16),
          
          // Stats chips
          Row(
            children: [
              Expanded(child: _buildStatChipSkeleton(context)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatChipSkeleton(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChipSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(context, width: 30, height: 14),
              const SizedBox(height: 2),
              _line(context, width: 40, height: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelectorSkeleton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              _line(context, width: 100, height: 14),
            ],
          ),
          Row(
            children: [
              Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarSkeleton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                _line(context, width: 150, height: 14),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
          decoration: BoxDecoration(
            color: AppColors.card(context),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 12),
              
              // Content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    _line(context, width: 120, height: 15),
                    const SizedBox(height: 4),
                    
                    // Payment info
                    _line(context, width: 100, height: 13),
                    const SizedBox(height: 4),
                    
                    // Progress bar
                    _line(context, width: double.infinity, height: 4, radius: BorderRadius.circular(2)),
                  ],
                ),
              ),
              
              // Status badge
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
        
        // Divider
        Container(
          height: 1,
          color: AppColors.border(context),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
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
      child: ListView(
        children: [
          // Stats card
          _buildStatsSkeleton(context, dark),
          
          // Month selector (if monthly event)
          if (isMonthlyy) ...[
            const SizedBox(height: 8),
            _buildMonthSelectorSkeleton(context),
            const SizedBox(height: 8),
          ],
          
          // Search bar
          _buildSearchBarSkeleton(context),
          
          // Participants list
          const SizedBox(height: 8),
          ...List.generate(5, (index) => _buildParticipantItemSkeleton(context, dark)),
        ],
      ),
    );
  }
}





