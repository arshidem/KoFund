// lib/features/events/skeletons/event_overview_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_colors.dart';

class EventOverviewSkeleton extends StatelessWidget {
  final bool? isDarkMode;

  const EventOverviewSkeleton({super.key, this.isDarkMode});

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
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
        children: [
          _buildHeaderInfoTileSkeleton(context),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            children: List.generate(4, (index) => _buildHeaderInfoTileSkeleton(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfoTileSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.05),
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
              color: Colors.white.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
      padding: const EdgeInsets.all(24),
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
          _line(context, width: 120, height: 13),
          const SizedBox(height: 8),
          _line(context, width: 180, height: 32),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItemSkeleton(context),
              _buildStatItemSkeleton(context),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              _line(context, width: 90, height: 12),
              _line(context, width: 100, height: 13),
            ]
          ),
          const SizedBox(height: 10),
          _line(context, width: double.infinity, height: 8, radius: BorderRadius.circular(10)),
        ],
      ),
    );
  }

  Widget _buildStatItemSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(context, width: 80, height: 18),
        const SizedBox(height: 4),
        _line(context, width: 60, height: 12),
      ],
    );
  }

  Widget _builInfoSkeleton(BuildContext context, bool dark) {
    return Card(
      color: AppColors.card(context),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border(context), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                _line(context, width: 100, height: 16),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < 6; i++) ...[
              _buildDetailTileSkeleton(context),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line(context, width: 80, height: 12),
                        const SizedBox(height: 2),
                        _line(context, width: 60, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              color: Colors.white.withValues(alpha: 0.3),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Financial summary skeleton
            _buildFinancialSummarySkeleton(context, dark),
            const SizedBox(height: 12),
            
            // Header skeleton
            _buildHeaderSkeleton(context, dark),
            const SizedBox(height: 12),
            
            // event info skeleton
            _builInfoSkeleton(context, dark),
          ],
        ),
      ),
    );
  }
}





