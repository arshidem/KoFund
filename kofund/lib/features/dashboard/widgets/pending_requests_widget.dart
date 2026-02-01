import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';
import 'package:kofund/core/providers/theme_provider.dart';

class PendingRequestsWidget extends StatefulWidget {
  const PendingRequestsWidget({super.key});

  @override
  State<PendingRequestsWidget> createState() => _PendingRequestsWidgetState();
}

class _PendingRequestsWidgetState extends State<PendingRequestsWidget> {
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final authProvider = context.read<AppAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final communityId = authProvider.user?.communityId;

    if (communityId != null) {
      await userProvider.loadCommunityMembers(communityId);
      setState(() {
        _pendingCount = userProvider.pendingMembers.length;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _pendingCount = 0;
      });
    }
  }

  void _navigateToApprovalScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ApprovalRequestsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final pendingCount = userProvider.pendingMembers.length;
        
        if (_isLoading && pendingCount == 0) {
          return _buildSkeleton(context);
        }

        if (pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: _navigateToApprovalScreen,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // ✅ Theme-aware background color
              color: _getContainerBackgroundColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getContainerBorderColor(context),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon with TOP-RIGHT badge
                    Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(right: 16),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Main icon container
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.card(context),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_add_alt_1,
                              color: _getIconColor(context),
                              size: 28,
                            ),
                          ),
                          
                          // ✅ TOP-RIGHT CORNER BADGE
                          Positioned(
                            top: -8,
                            right: -8,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.error(context), // Using error color for badge
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.card(context),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  pendingCount > 9 ? '9+' : pendingCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Pending Join Requests",
                            style: TextStyle(
                              color: _getTitleColor(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pendingCount == 1
                                ? "1 request waiting for approval"
                                : "$pendingCount requests waiting for approval",
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Review Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToApprovalScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(context),
                      foregroundColor: _getButtonTextColor(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                      shadowColor: _getButtonColor(context).withValues(alpha: 0.3),
                    ),
                    child: Text(
                      "Review Requests",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ Helper methods for theme-aware colors
  Color _getContainerBackgroundColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode 
        ? const Color(0xFF2A1F00).withValues(alpha: 0.8) // Dark yellow-brown
        : const Color(0xFFFFF3D9); // Light cream-yellow
  }

  Color _getContainerBorderColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode 
        ? const Color(0xFF4A3C00).withValues(alpha: 0.6)
        : const Color(0xFFFFE0B2);
  }

  Color _getIconColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode 
        ? const Color(0xFFFFB74D) // Dark theme orange
        : const Color(0xFFFF9800); // Light theme orange
  }

  Color _getTitleColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode 
        ? const Color(0xFFFFB74D) // Dark theme orange
        : const Color(0xFFFF9800); // Light theme orange
  }

  Color _getButtonColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode 
        ? const Color(0xFFFF9800) // Orange for both themes
        : const Color(0xFFFF9800);
  }

  Color _getButtonTextColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode 
        ? Colors.black // Dark text on orange in dark mode
        : Colors.white; // White text on orange in light mode
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? AppColors.darkCard.withValues(alpha: 0.5)
            : AppColors.lightCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
              ? AppColors.darkBorder.withValues(alpha: 0.3)
              : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Skeleton icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? AppColors.darkTextSecondary.withValues(alpha: 0.2)
                  : AppColors.lightTextSecondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Skeleton text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? AppColors.darkTextSecondary.withValues(alpha: 0.2)
                        : AppColors.lightTextSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? AppColors.darkTextSecondary.withValues(alpha: 0.2)
                        : AppColors.lightTextSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
