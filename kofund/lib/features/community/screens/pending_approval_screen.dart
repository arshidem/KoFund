import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../screens/join_community_screen.dart';
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isLeavingCommunity = false;
  bool _isCheckingStatus = false;
  
  @override
  void initState() {
    super.initState();
    // Cancel any existing listener
    _checkUserApprovalOnLoad();
  }

  // Check approval status when screen loads
  void _checkUserApprovalOnLoad() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    if (mounted) {
      final authProvider = context.read<AppAuthProvider>();
      if (authProvider.user?.isApproved == true) {
        _navigateToDashboard();
      }
    }
  }

  // Navigate to dashboard
  void _navigateToDashboard() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, RouteNames.communityDashboard);
    }
  }

  // Check status manually (when button is pressed)
  Future<void> _checkStatus() async {
    if (!mounted) return;
    
    setState(() => _isCheckingStatus = true);
    
    try {
      final authProvider = context.read<AppAuthProvider>();
      
      // 1. Force refresh user data from Firestore
      await authProvider.refreshUserData();
      if (!mounted) return;
      
      // 2. Check if user is now approved
      if (authProvider.user?.isApproved == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 You have been approved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate after delay
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        _navigateToDashboard();
      } else {
        // Still not approved
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still waiting for admin approval...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to check status: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approval'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Main Content Card
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.pending_actions,
                          size: 60,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Status Title
                      Text(
                        'Waiting for Admin Approval',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Status Description
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border(context),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Your request to join the community has been sent to the admin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary(context),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You will be able to access the community dashboard once approved.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary(context),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Info Card
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withValues(alpha: 0.15),
                              Colors.orange.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 20,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'What happens next?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Feature list
                            Column(
                              children: [
                                _buildFeatureItem(
                                  'Community admin will review your request',
                                  Colors.orange.shade800,
                                ),
                                _buildFeatureItem(
                                  'You\'ll receive notification when approved',
                                  Colors.orange.shade800,
                                ),
                                _buildFeatureItem(
                                  'Access community dashboard after approval',
                                  Colors.orange.shade800,
                                ),
                                _buildFeatureItem(
                                  'Or join a different community anytime',
                                  Colors.orange.shade800,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isCheckingStatus ? null : _checkStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isCheckingStatus
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.refresh, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Check Status',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLeavingCommunity
                              ? null
                              : () {
                                  _showLeaveCommunityDialog(context, authProvider);
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.border(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: AppColors.surface(context),
                          ),
                          child: _isLeavingCommunity
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.group_add, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Join Different Community',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Help Text
                      Text(
                        'Need help? Contact the community admin',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
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
    );
  }

  Widget _buildFeatureItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 28),
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: color,
              ),
            ),
          ),
        ],
      )
    );
  }

  void _showLeaveCommunityDialog(
      BuildContext context, AppAuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Leave Community?'),
          ],
        ),
        content: const Text(
          'Do you want to leave this community and join a different one?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveCommunity(context, authProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Leave Community'),
          ),
        ],
      ),
    );
  }

Future<void> _leaveCommunity(
    BuildContext context, AppAuthProvider authProvider) async {
  
  // Show loading state
  setState(() => _isLeavingCommunity = true);
  
  // Fire and forget - leave community in background
  Future.microtask(() async {
    try {
      await authProvider.removeUserFromCommunity();
    } catch (e) {
      debugPrint('Leave community background error: $e');
    }
  });
  
  // Navigate immediately
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JoinCommunityScreen()),
      (route) => false,
    );
  });
}
}
