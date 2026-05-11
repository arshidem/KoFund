// lib/core/skeleton/approval_requests_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ApprovalRequestsSkeleton extends StatelessWidget {
  const ApprovalRequestsSkeleton({super.key});

  static Widget buildList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final itemColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: 160,
              height: 18,
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        ...List.generate(3, (i) => Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: _buildItem(context, itemColor, showApproveButtons: true),
        )),
        const SizedBox(height: 12),
        // Section header skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: 140,
              height: 18,
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        ...List.generate(4, (i) => Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: _buildItem(context, itemColor, showApproveButtons: false),
        )),
      ],
    );
  }

  static Widget _buildItem(BuildContext context, Color itemColor, {required bool showApproveButtons}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: itemColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          // Name + contact
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: itemColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 160,
                  height: 10,
                  decoration: BoxDecoration(
                    color: itemColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          if (showApproveButtons) ...[
            const SizedBox(width: 8),
            Container(
              width: 60,
              height: 28,
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 60,
              height: 28,
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ] else ...[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: itemColor),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}





