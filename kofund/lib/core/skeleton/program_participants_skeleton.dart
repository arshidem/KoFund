// lib/features/programs/skeletons/program_participants_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_colors.dart';

class ProgramParticipantsSkeleton extends StatelessWidget {
  final bool? isDarkMode;
  final bool isMonthlyProgram;

  const ProgramParticipantsSkeleton({
    super.key,
    this.isDarkMode,
    this.isMonthlyProgram = false,
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
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary(context).withOpacity(0.1),
            AppColors.primary(context).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
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
                  _line(context, width: 80, height: 11),
                  if (isMonthlyProgram) ...[
                    const SizedBox(height: 4),
                    _line(context, width: 100, height: 13),
                  ],
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _line(context, width: 20, height: 16),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Amount
          _line(context, width: 100, height: 26),
          const SizedBox(height: 2),
          _line(context, width: 120, height: 11),
          
          const SizedBox(height: 8),
          
          // Progress bar
          _line(context, width: double.infinity, height: 6, radius: BorderRadius.circular(4)),
          
          const SizedBox(height: 10),
          
          // Stats chips
          Row(
            children: [
              Expanded(child: _buildStatChipSkeleton(context)),
              const SizedBox(width: 8),
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
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.1),
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
                  color: Colors.white.withOpacity(0.1),
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
                  color: Colors.white.withOpacity(0.1),
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
          
          // Month selector (if monthly program)
          if (isMonthlyProgram) ...[
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