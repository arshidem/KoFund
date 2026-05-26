import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppConfigSkeleton extends StatelessWidget {
  const AppConfigSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1
          _buildShimmerText(baseColor, highlightColor, width: 120, height: 18),
          const SizedBox(height: 16),
          _buildShimmerInput(baseColor, highlightColor),
          const SizedBox(height: 16),
          _buildShimmerInput(baseColor, highlightColor),
          
          const SizedBox(height: 32),
          
          // Section 2
          _buildShimmerText(baseColor, highlightColor, width: 150, height: 18),
          const SizedBox(height: 16),
          _buildShimmerInput(baseColor, highlightColor),
          const SizedBox(height: 16),
          _buildShimmerInput(baseColor, highlightColor, height: 100), // Multiline
          
          const SizedBox(height: 48),
          
          // Button
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerText(Color baseColor, Color highlightColor, {double width = 100, double height = 14}) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildShimmerInput(Color baseColor, Color highlightColor, {double height = 56}) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height > 60 ? 24 : 100),
        ),
      ),
    );
  }
}





