import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isCheckingStatus = false;
  bool _isLeavingCommunity = false;

  Future<void> _leaveAndJoinAnother() async {
    setState(() => _isLeavingCommunity = true);
    try {
      final profileProvider = context.read<ProfileProvider>();
      final authProvider = context.read<AppAuthProvider>();
      
      final success = await profileProvider.leaveCommunity();
      if (!mounted) return;
      
      if (success) {
        await authProvider.refreshUserData();
        if (!mounted) return;
        SnackbarHelper.showSuccess(context, 'Left current community. Choose a new one.');
        context.go(RouteNames.joinCommunity);
      } else {
        SnackbarHelper.showError(
          context,
          profileProvider.error ?? 'Failed to leave community',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLeavingCommunity = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkUserApprovalOnLoad();
  }

  void _checkUserApprovalOnLoad() async {
    // Start listening to auth changes for automatic redirection if rejected
    final authProvider = context.read<AppAuthProvider>();
    authProvider.addListener(_onAuthStatusChanged);

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    if (authProvider.user?.isApproved == true) {
      _navigateToDashboard();
    }
  }

  void _onAuthStatusChanged() {
    if (!mounted) return;
    final authProvider = context.read<AppAuthProvider>();
    
    // 1. If user is now approved, go to dashboard
    if (authProvider.user?.isApproved == true) {
      authProvider.removeListener(_onAuthStatusChanged);
      _navigateToDashboard();
    } 
    // 2. If user is no longer in a community (REJECTED), go to join community
    else if (authProvider.user?.communityId == null && !authProvider.isLoading) {
      authProvider.removeListener(_onAuthStatusChanged);
      if (mounted) {
        context.go(RouteNames.joinCommunity);
      }
    }
  }

  @override
  void dispose() {
    // Safe removal of listener
    try {
      context.read<AppAuthProvider>().removeListener(_onAuthStatusChanged);
    } catch (_) {}
    super.dispose();
  }

  void _navigateToDashboard() {
    if (mounted) {
      context.go(RouteNames.communityDashboard);
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final authProvider = context.read<AppAuthProvider>();
      await authProvider.refreshUserData();
      if (!mounted) return;
      
      if (authProvider.user?.isApproved == true) {
        _navigateToDashboard();
      } else {
        SnackbarHelper.showInfo(context, 'Still waiting for admin approval...');
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Verification',
      automaticallyImplyLeading: false,
      body: Padding(
        padding: AppStyles.screenPadding,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Concentric Circle Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_moon_outlined,
                      size: 48,
                      color: AppColors.primary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Main Text
              Text(
                "Verification in Progress",
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Your membership is currently being reviewed by community administrators.",
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.border(context),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: Colors.orange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Current Status",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Waiting for Admin Approval",
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
              
              // Actions
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isCheckingStatus ? null : _checkStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                  ),
                  child: _isCheckingStatus
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Refresh Status",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLeavingCommunity || _isCheckingStatus ? null : _leaveAndJoinAnother,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary(context).withValues(alpha: 0.5), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      backgroundColor: AppColors.surface(context),
                      foregroundColor: AppColors.primary(context),
                    ),
                    child: _isLeavingCommunity
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Join another community",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}







