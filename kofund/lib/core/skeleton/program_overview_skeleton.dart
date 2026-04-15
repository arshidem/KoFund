// lib/features/programs/skeletons/program_overview_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_colors.dart';

class ProgramOverviewSkeleton extends StatelessWidget {
  final bool? isDarkMode;

  const ProgramOverviewSkeleton({super.key, this.isDarkMode});

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

  Widget _buildHeaderSkeleton(BuildContext context, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program Title skeleton
          _line(context, width: 200, height: 22),
          const SizedBox(height: 16),
          
          // Participants status skeleton
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _line(context, width: 80, height: 14),
                  ],
                ),
                Row(
                  children: [
                    _line(context, width: 30, height: 18),
                    const SizedBox(width: 4),
                    _line(context, width: 40, height: 14),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Info grid skeleton
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            children: List.generate(4, (index) => _buildInfoTileSkeleton(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTileSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(context, width: 40, height: 11),
                const SizedBox(height: 2),
                _line(context, width: 60, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummarySkeleton(BuildContext context, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 6),
              _line(context, width: 120, height: 15),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Top stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) => _buildMetricSkeleton(context)),
          ),
          
          const SizedBox(height: 16),
          
          // Progress section
          _line(context, width: 100, height: 12),
          const SizedBox(height: 4),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _line(context, width: 80, height: 16),
              _line(context, width: 40, height: 14),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Progress bar
          _line(context, width: double.infinity, height: 6, radius: BorderRadius.circular(4)),
          
          const SizedBox(height: 6),
          _line(context, width: 120, height: 11),
        ],
      ),
    );
  }

  Widget _buildMetricSkeleton(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        _line(context, width: 40, height: 11),
        const SizedBox(height: 2),
        _line(context, width: 50, height: 14),
      ],
    );
  }

  Widget _buildProgramInfoSkeleton(BuildContext context, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border(context), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 8),
              _line(context, width: 120, height: 16),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Detail tiles
          for (int i = 0; i < 4; i++) ...[
            _buildDetailTileSkeleton(context),
            if (i < 3) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailTileSkeleton(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(context, width: 80, height: 13),
              const SizedBox(height: 4),
              _line(context, width: 140, height: 15),
            ],
          ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            _buildHeaderSkeleton(context, dark),
            const SizedBox(height: 12),
            
            // Financial summary skeleton
            _buildFinancialSummarySkeleton(context, dark),
            const SizedBox(height: 12),
            
            // Program info skeleton
            _buildProgramInfoSkeleton(context, dark),
            const SizedBox(height: 12),
            
            // Program status skeleton
            _buildProgramInfoSkeleton(context, dark), // Reuse same style
          ],
        ),
      ),
    );
  }
}
