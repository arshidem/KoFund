// lib/core/skeleton/member_list_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MemberListSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const MemberListSkeleton({super.key, required this.isDarkMode});

  Color _baseColor() =>
      isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;

  Color _highlightColor() =>
      isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

  Color _itemColor() =>
      isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  static Widget buildSliver(BuildContext context, bool isDarkMode) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildShimmerItem(context, isDarkMode),
        childCount: 8,
      ),
    );
  }

  static Widget _buildShimmerItem(BuildContext context, bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;
    final itemColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: _buildMemberItemSkeleton(context, itemColor),
    );
  }

  static Widget _buildMemberItemSkeleton(BuildContext context, Color itemColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
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
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 110,
                      height: 14,
                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: itemColor),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: itemColor.withValues(alpha: 0.1)),
      ],
    );
  }
}

