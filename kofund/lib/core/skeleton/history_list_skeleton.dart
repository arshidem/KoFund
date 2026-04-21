// lib/core/skeleton/history_list_skeleton.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:shimmer/shimmer.dart';

class HistoryListSkeleton extends StatelessWidget {
  final bool? isDarkMode;

  const HistoryListSkeleton({super.key, this.isDarkMode});

  Widget _line(
    BuildContext context, {
    double width = double.infinity,
    double height = 12,
    BorderRadius? radius,
  }) {
    final bool dark =
        isDarkMode ?? Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? Colors.grey[700] : Colors.grey[300],
        borderRadius: radius ?? BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildTransactionSkeleton(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Leading circular icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 12),

              // Title & subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(context, width: 140, height: 14),
                    const SizedBox(height: 6),
                    _line(context, width: 90, height: 12),
                  ],
                ),
              ),

              // Time & amount (right aligned)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _line(context, width: 48, height: 12),
                  const SizedBox(height: 6),
                  _line(context, width: 80, height: 16),
                ],
              ),
            ],
          ),
        ),

        // Divider like screenshot
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark =
        isDarkMode ?? Theme.of(context).brightness == Brightness.dark;

    final baseColor = dark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = dark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return _buildTransactionSkeleton(context);
        },
      ),
    );
  }
}

