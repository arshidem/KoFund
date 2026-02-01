// lib/core/skeleton/member_list_skeleton.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';
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
    return Shimmer.fromColors(
      baseColor: _baseColor(),
      highlightColor: _highlightColor(),
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _itemColor(),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Container(
                            width: 140,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _itemColor(),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Phone number
                          Container(
                            width: 110,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _itemColor(),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Chevron
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _itemColor(),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

