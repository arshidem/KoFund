// lib/core/skeleton/issue_reports_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_dimensions.dart';

class IssueReportsSkeleton extends StatelessWidget {
  const IssueReportsSkeleton({super.key});

  static Widget getSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final itemColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats card skeleton
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Issues list
          ...List.generate(5, (i) => Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: _buildIssueCard(context, itemColor),
          )),
        ],
      ),
    );
  }

  static Widget _buildIssueCard(BuildContext context, Color itemColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: itemColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: itemColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ttitle
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                // Badges row
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 18,
                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 60,
                      height: 18,
                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Description lines
                Container(
                  width: double.infinity,
                  height: 11,
                  decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 200,
                  height: 11,
                  decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                // Footer
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: itemColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => getSkeleton(context);
}





