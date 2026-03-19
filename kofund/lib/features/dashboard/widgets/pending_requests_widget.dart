import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';

class PendingRequestsWidget extends StatefulWidget {
  const PendingRequestsWidget({super.key});

  @override
  State<PendingRequestsWidget> createState() => _PendingRequestsWidgetState();
}

class _PendingRequestsWidgetState extends State<PendingRequestsWidget> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AppAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final communityId = authProvider.user?.communityId;

    if (communityId != null) {
      await userProvider.loadCommunityMembers(communityId);
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
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
        
        if (pendingCount == 0 && !_isLoading) {
          return const SizedBox.shrink();
        }

        if (_isLoading && pendingCount == 0) {
          return _buildSkeleton(context);
        }

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.primary(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Status Indicator (Vertical Gradient Bar)
                      Container(
                        width: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary(context),
                              AppColors.primary(context).withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                      
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          child: Row(
                            children: [
                              // Icon with subtle glow
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary(context).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_add_rounded,
                                  color: AppColors.primary(context),
                                  size: 26,
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Text Content
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Pending Approvals",
                                      style: TextStyle(
                                        color: AppColors.textPrimary(context),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pendingCount == 1
                                          ? "1 user is waiting to join"
                                          : "$pendingCount users are waiting to join",
                                      style: TextStyle(
                                        color: AppColors.textSecondary(context),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Action Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _navigateToApprovalScreen,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary(context),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary(context).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Review",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
