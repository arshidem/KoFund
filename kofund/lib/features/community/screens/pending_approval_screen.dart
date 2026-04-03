import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isCheckingStatus = false;

  // Hardcoded Colors for Premium Feel
  final Color bgColor = const Color(0xFF0F1716);
  final Color primaryColor = const Color(0xFF00D2B4);
  final Color cardColor = const Color(0xFF1A2423);
  final Color textPrimary = const Color(0xFFFFFFFF);
  final Color textSecondary = const Color(0xFF94A3B8);
  final Color accentColor = const Color(0xFFFBBF24);

  @override
  void initState() {
    super.initState();
    _checkUserApprovalOnLoad();
  }

  void _checkUserApprovalOnLoad() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.user?.isApproved == true) {
      _navigateToDashboard();
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Still waiting for admin approval...'),
            backgroundColor: accentColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Verification in Progress',
      automaticallyImplyLeading: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              // Minimal Illustration / Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
                ),
                child: Center(
                  child: Icon(Icons.shield_moon_outlined, size: 48, color: primaryColor),
                ),
              ),
              const SizedBox(height: 40),
              // Main Text
              Text(
                "Verification in Progress",
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Your membership request is being reviewed by the community administrators. You'll have full access once verified.",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Actions
              _buildBigButton(
                onTap: _isCheckingStatus ? null : _checkStatus,
                child: _isCheckingStatus 
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: bgColor))
                  : Text("Check Status", style: TextStyle(color: bgColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Leave Community",
                  style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigButton({required VoidCallback? onTap, required Widget child}) {
    return Material(
      color: onTap == null ? primaryColor.withOpacity(0.5) : primaryColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 60,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
