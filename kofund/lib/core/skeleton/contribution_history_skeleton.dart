// lib/core/skeleton/contribution_history_skeleton.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:shimmer/shimmer.dart';

class ContributionHistorySkeleton extends StatelessWidget {
  final bool isDarkMode;

  const ContributionHistorySkeleton({super.key, required this.isDarkMode});

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
      child: CustomScrollView(
        slivers: [
          // Stats cards skeleton
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCardSkeleton(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCardSkeleton(),
                  ),
                ],
              ),
            ),
          ),

          // List items skeleton
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildListItemSkeleton(),
              childCount: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: _itemColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 80,
            height: 18,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 14,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItemSkeleton() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar/Icon skeleton
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _itemColor(),
                ),
              ),
              const SizedBox(width: 12),

              // Text content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title skeleton
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _itemColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle skeleton
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _itemColor(),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 80,
                          height: 12,
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

              // Amount and time skeleton
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 50,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _itemColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 70,
                    height: 16,
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

        // Divider
        Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: _lightItemColor(),
        ),
      ],
    );
  }
}

// Skeleton for the contribution details bottom sheet
class ContributionDetailsSkeleton extends StatelessWidget {
  final bool isDarkMode;
  final bool hasEditHistory;

  const ContributionDetailsSkeleton({
    super.key,
    required this.isDarkMode,
    this.hasEditHistory = false,
  });

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
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F1F1D) : const Color(0xFFF8FDFC),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _itemColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 160,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _itemColor(),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 200,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _itemColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  if (hasEditHistory)
                    Container(
                      width: 60,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _itemColor(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount card
                    _buildAmountCardSkeleton(),
                    const SizedBox(height: 24),

                    // Basic information header
                    _buildSectionHeaderSkeleton(),
                    const SizedBox(height: 16),

                    // Info card
                    _buildInfoCardSkeleton(),
                    
                    if (hasEditHistory) ...[
                      const SizedBox(height: 24),
                      Divider(color: _lightItemColor()),
                      const SizedBox(height: 24),
                      
                      // Edit history header
                      _buildSectionHeaderSkeleton(),
                      const SizedBox(height: 16),
                      
                      // Edit history items
                      for (int i = 0; i < 2; i++) ...[
                        _buildEditHistoryItemSkeleton(),
                        if (i < 1) const SizedBox(height: 12),
                      ],
                    ],
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: BoxDecoration(
                color: _lightItemColor(),
                border: Border(
                  top: BorderSide(color: _itemColor()),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _itemColor(),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _itemColor(),
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  Widget _buildAmountCardSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _itemColor(),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 30,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 180,
            height: 16,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 28,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderSkeleton() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _itemColor(),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 120,
          height: 18,
          decoration: BoxDecoration(
            color: _itemColor(),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCardSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _itemColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInfoRowSkeleton(),
          const SizedBox(height: 16),
          Divider(color: _lightItemColor()),
          const SizedBox(height: 16),
          _buildInfoRowSkeleton(),
        ],
      ),
    );
  }

  Widget _buildInfoRowSkeleton() {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _lightItemColor(),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 11,
              decoration: BoxDecoration(
                color: _lightItemColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 120,
              height: 14,
              decoration: BoxDecoration(
                color: _lightItemColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditHistoryItemSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _itemColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: _lightItemColor(),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: _lightItemColor(),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 14,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 150,
            height: 12,
            decoration: BoxDecoration(
              color: _lightItemColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}