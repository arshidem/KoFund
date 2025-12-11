// lib/core/skeleton/member_list_skeleton.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';

class MemberListSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const MemberListSkeleton({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8, // Show 8 skeleton items
      itemBuilder: (context, index) {
        return _buildMemberCardSkeleton();
      },
    );
  }

  Widget _buildMemberCardSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Avatar skeleton
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and admin badge skeleton
                  Row(
                    children: [
                      // Name skeleton
                      Container(
                        width: 120,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Admin badge skeleton
                      Container(
                        width: 50,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Email skeleton
                  Container(
                    width: 180,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Join date skeleton
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            
            // Chevron skeleton
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}