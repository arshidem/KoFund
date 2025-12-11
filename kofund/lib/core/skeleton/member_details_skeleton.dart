// lib/core/skeleton/member_details_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/core/constants/app_colors.dart';

/// Skeleton loader for Member Details screen.
/// Mirrors the real screen structure:
/// - Profile header card
/// - Member info card
/// - Participation history card (few rows)
/// - Contribution history card (few rows)
/// - Privacy notice block
class MemberDetailsSkeleton extends StatelessWidget {
  final bool? isDarkMode;

  const MemberDetailsSkeleton({super.key, this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;

    final baseColor = dark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = dark ? Colors.grey[700]! : Colors.grey[100]!;

    Widget line({double width = double.infinity, double height = 12, BorderRadius? radius}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius ?? BorderRadius.circular(4),
        ),
      );
    }

    Widget cardPlaceholder({bool hasGradient = false, required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasGradient ? null : (dark ? Colors.grey[850] : Colors.white),
          gradient: hasGradient ? AppColors.primaryGradient(context) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!hasGradient)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: child,
      );
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Profile Header Card (Horizontal Rectangle) - with gradient
            Padding(
              padding: const EdgeInsets.all(16),
              child: cardPlaceholder(
                hasGradient: true,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        // Initial Circle Avatar
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(35),
                          ),
                        ),
                        const SizedBox(width: 20),
                        
                        // Member Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Row(
                                children: [
                                  line(width: 150, height: 22),
                                  const Spacer(),
                                  Container(
                                    width: 60,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Email
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  line(width: 180, height: 14),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Phone
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  line(width: 120, height: 14),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Three-dot menu position
                    Positioned(
                      top: -8,
                      right: -10,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Member Information Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: cardPlaceholder(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        line(width: 160, height: 18),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Info Items
                    for (int i = 0; i < 4; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  line(width: 60, height: 12),
                                  const SizedBox(height: 4),
                                  line(width: 120, height: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Admin section divider
                    Container(height: 12),
                    line(width: double.infinity, height: 1),
                    Container(height: 12),
                    
                    // Admin View title
                    line(width: 100, height: 16),
                    const SizedBox(height: 8),
                    
                    // Admin info items
                    for (int i = 0; i < 3; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  line(width: 80, height: 12),
                                  const SizedBox(height: 4),
                                  line(width: 140, height: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Participation History Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: cardPlaceholder(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with count
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        line(width: 180, height: 18),
                        const Spacer(),
                        Container(
                          width: 40,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Stats badges
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Participation Items
                    for (int i = 0; i < 3; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: dark ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      line(width: 150, height: 16),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          line(width: 80, height: 12),
                                          const SizedBox(width: 12),
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          line(width: 60, height: 12),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 60,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Progress bar
                            line(width: double.infinity, height: 6, radius: BorderRadius.circular(4)),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: line(width: 60, height: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // "More" indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: line(width: 100, height: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            // Contribution History Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: cardPlaceholder(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with total amount
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        line(width: 180, height: 18),
                        const Spacer(),
                        Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Stats badges
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 100,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Contribution Items
                    for (int i = 0; i < 3; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: dark ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  line(width: 140, height: 15),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      line(width: 80, height: 12),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 60,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                line(width: 80, height: 18),
                                const SizedBox(height: 6),
                                line(width: 40, height: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // "More" indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: line(width: 120, height: 14),
                    ),
                  ],
                ),
              ),
            ),

            // Privacy Notice Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          line(width: 200, height: 14),
                          const SizedBox(height: 8),
                          line(width: double.infinity, height: 12),
                          const SizedBox(height: 4),
                          line(width: 180, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}