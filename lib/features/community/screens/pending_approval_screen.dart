import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
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
        Navigator.pushReplacementNamed(context, RouteNames.joinCommunity);
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
      Navigator.pushReplacementNamed(context, RouteNames.communityDashboard);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              // Premium Illustration / Icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary(context).withValues(alpha: 0.15),
                      AppColors.primary(context).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_moon_outlined,
                      size: 56,
                      color: AppColors.primary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
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
              const SizedBox(height: 40),

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

              const Spacer(),
              
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
                    onPressed: () async {
                      await context.read<AppAuthProvider>().signOut(context);
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, RouteNames.login);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error(context).withValues(alpha: 0.5), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      backgroundColor: AppColors.surface(context),
                      foregroundColor: AppColors.error(context),
                    ),
                    child: const Text(
                      "Sign out from account",
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







