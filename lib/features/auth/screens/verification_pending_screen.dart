// lib/features/auth/screens/verification_pending_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart'; // Add AppColors
import '../../../core/utils/snackbar_helper.dart'; // Consistent with other screens
import '../../../routing/route_names.dart'; // Use route nnames
import '../providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:go_router/go_router.dart';

class VerificationPendingScreen extends StatefulWidget {
  final String email;
  final String? pendingInviteCode;
  
  const VerificationPendingScreen({
    super.key, 
    required this.email,
    this.pendingInviteCode,
  });

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> 
    with SingleTickerProviderStateMixin { // ⭐ ADD THIS MIXIN
  bool _isResending = false;
  bool _isChecking = false;
  Timer? _verificationTimer;
  late AnimationController _rotationController; // ⭐ Rename to match usage

  @override
  void initState() {
    super.initState();
    
    // Initialize rotation animation
    _rotationController = AnimationController( // ⭐ Use consistent name
      duration: const Duration(seconds: 1),
      vsync: this, // ⭐ Now 'this' works because we added the mixin
    )..repeat(); // Auto-repeat
    
    _startAutoVerificationCheck();
    _checkForPendingInvite();
  }

@override
void dispose() {
  _rotationController.dispose();
  _verificationTimer?.cancel();
  super.dispose();
}

// ⭐ ADD THIS METHOD (missing from your code)
Future<void> _checkForPendingInvite() async {
  if (widget.pendingInviteCode != null && widget.pendingInviteCode!.isNotEmpty) {
    debugPrint('🎯 Verification screen has pending invite: ${widget.pendingInviteCode}');
  }
}
  // Auto-check verification status every 5 seconds
  void _startAutoVerificationCheck() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkVerificationStatus();
    });
  }

  Future<void> _checkVerificationStatus() async {
    if (_isChecking) return;
    
    setState(() => _isChecking = true);
    
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null && currentUser.emailVerified && mounted) {
        // Email verified - stop timer AND rotation
        _verificationTimer?.cancel();
        _rotationController.stop(); // Stop the rotation
        
        // Show success message using AppColors
        SnackbarHelper.showSuccess(context, 'Email verified successfully!');
        
        // ⭐ NEW: Check if we have a pending invite code
        if (widget.pendingInviteCode != null) {
          debugPrint('✅ Email verified with invite code, saving to storage');
          
          // Save invite code for after splash screen
          final prefs = await SharedPreferences.getInstance();
          if (!mounted) return;
          await prefs.setString('pending_invite_code', widget.pendingInviteCode!);
          if (!mounted) return;
          
          // Navigate to splash screen which will handle the invite
          context.go('/splash?code=${widget.pendingInviteCode}');
        } else {
          // Check storage for any pending invites
          final prefs = await SharedPreferences.getInstance();
          final storedInviteCode = prefs.getString('pending_invite_code');
          
          if (storedInviteCode != null && storedInviteCode.isNotEmpty) {
            debugPrint('📋 Found stored invite code after verification: $storedInviteCode');
            
            // Navigate to splash screen with stored invite
            context.go('/splash?code=$storedInviteCode');
          } else {
            // Normal flow - no invite
            context.go('/splash');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking verification: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to check verification status');
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final success = await authProvider.resendVerificationEmail();
    if (!mounted) return;
    
    if (success && mounted) {
      SnackbarHelper.showSuccess(context, 'Verification email sent!');
    } else if (mounted) {
      SnackbarHelper.showError(
        context, 
        authProvider.error ?? 'Failed to resend email'
      );
    }
    
    if (mounted) {
      setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    await authProvider.signOut(context);
    if (!mounted) return;
    
    if (mounted) {
      context.go(RouteNames.login);
    }
  }

  Widget _buildInviteBanner() {
    if (widget.pendingInviteCode == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        gradient: LinearGradient(
          colors: [
            AppColors.primary(context).withValues(alpha: 0.15),
            AppColors.primary(context).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.primary(context).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_rounded,
            size: 20,
            color: AppColors.primary(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Invite',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.pendingInviteCode!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 20,
              color: AppColors.primary(context),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.pendingInviteCode!));
              SnackbarHelper.showInfo(context, 'Invite code copied to clipboard');
            },
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GradientSheetScaffold(
      title: 'Verify Your Email',
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        onPressed: _signOut,
        tooltip: 'Sign Out',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // ✅ Consistent with PendingApprovalScreen layout
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Status Icon (similar to PendingApprovalScreen)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          size: 60,
                          color: AppColors.primary(context),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Status Ttitle
                      Text(
                        'Verify Your Email Address',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Email Address Display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          
                            horizontal: 20, vertical: 16),
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
                              'Verification link sent to:',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary(context),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.email,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary(context),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Invite Banner (if exists)
                      if (widget.pendingInviteCode != null) ...[
                        _buildInviteBanner(),
                        const SizedBox(height: 12),
                      ],

                      // Info Card (similar to PendingApprovalScreen)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary(context).withValues(alpha: 0.15),
                              AppColors.primary(context).withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppColors.primary(context).withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
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
                                  color: AppColors.primary(context),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'What happens next?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Feature list
                            Column(
                              children: [
                                _buildFeatureItem(
                                  'Check your email inbox (and spam folder)',
                                  AppColors.textSecondary(context),
                                  Icons.email_rounded,
                                ),
                                _buildFeatureItem(
                                  'Click the verification link in the email',
                                  AppColors.textSecondary(context),
                                  Icons.link_rounded,
                                ),
                                _buildFeatureItem(
                                  'Return to app - it will update automatically',
                                  AppColors.textSecondary(context),
                                  Icons.autorenew_rounded,
                                ),
                                if (widget.pendingInviteCode != null)
                                  _buildFeatureItem(
                                    'After verification, you\'ll join the invited community',
                                    AppColors.textSecondary(context),
                                    Icons.group_add_rounded,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Auto-check status indicator
               // Auto-check status indicator with rotating icon
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.surface(context),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: AppColors.border(context),
    ),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Rotating icon using AnimationController
      RotationTransition(
        turns: Tween(begin: 0.0, end: 1.0).animate(_rotationController),
        child: Icon(
          Icons.autorenew_rounded,
          size: 20,
          color: _verificationTimer != null 
              ? AppColors.primary(context) 
              : Colors.green.shade600,
        ),
      ),
      const SizedBox(width: 12),
      Text(
        _verificationTimer != null 
            ? '🔄 Auto-checking every 5 seconds...'
            : '✅ Email verification complete!',
        style: TextStyle(
          fontSize: 14,
          color: _verificationTimer != null 
              ? AppColors.primary(context)
              : Colors.green.shade700,
        ),
      ),
    ],
  ),
),

                      const SizedBox(height: 12),

                      // Action Buttons (consistent styling)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isResending ? null : _resendVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isResending
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
                                    Icon(Icons.send_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Resend Verification Email',
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
                          onPressed: _signOut,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.error(context).withValues(alpha: 0.5), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            backgroundColor: AppColors.surface(context),
                            foregroundColor: AppColors.error(context),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.exit_to_app_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Sign Out & Try Different Account',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Help Text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border(context).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 24,
                              color: AppColors.textSecondary(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Need help with verification?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Check spam/junk folder\n• Ensure email is correct\n• Wait 2-3 minutes for delivery\n• Try resend if not received',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(context),
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
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
}





