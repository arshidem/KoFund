// lib/core/skeleton/participation_history_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ParticipationHistorySkeleton extends StatelessWidget {
  final bool isDarkMode;

  const ParticipationHistorySkeleton({super.key, required this.isDarkMode});

  Color _baseColor() =>
      isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;

  Color _highlightColor() =>
      isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

  Color _itemColor() =>
      isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

  Color _lightItemColor() =>
      isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor(),
      highlightColor: _highlightColor(),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: 6,
        itemBuilder: (context, index) => _buildParticipationCardSkeleton(),
      ),
    );
  }

  Widget _buildParticipationCardSkeleton() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Program Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _itemColor(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _itemColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _itemColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  width: 60,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _itemColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Program Type
            Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: _itemColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: _itemColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contribution Info Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _itemColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 50,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _itemColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Amount info
            Container(
              width: 150,
              height: 14,
              decoration: BoxDecoration(
                color: _itemColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),

            // Progress bar
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: _itemColor(),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),

            // Progress label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _itemColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 100,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _itemColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
