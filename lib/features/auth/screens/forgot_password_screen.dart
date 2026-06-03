// lib/features/auth/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/constants/app_styles.dart';
import '../providers/app_auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _cleanAuthErrorMessage(String message) {
    final lower = message.toLowerCase();
    
    if (lower.contains('user-not-found') || 
        lower.contains('no user found') ||
        lower.contains('user not found')) {
      return 'No account found with this email.';
    }
    
    if (lower.contains('invalid-email') || 
        lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    if (lower.contains('too-many-requests') || 
        lower.contains('too many requests')) {
      return 'Too many attempts. Please try again later.';
    }

    if (lower.contains('network-request-failed') || 
        lower.contains('network error') ||
        lower.contains('internet')) {
      return 'Network error. Please check your internet connection.';
    }

    return 'Could not process request. Please check your email and try again.';
  }

  Future<void> _submitResetRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AppAuthProvider>();
    authProvider.clearError();
    
    final success = await authProvider.sendPasswordResetEmail(_emailController.text.trim());

    if (success && mounted) {
      setState(() {
        _emailSent = true;
      });
    } else if (mounted && authProvider.error != null) {
      final cleanMsg = _cleanAuthErrorMessage(authProvider.error!);
      SnackbarHelper.showError(context, cleanMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Reset Password',
      body: Padding(
        padding: AppStyles.screenPadding,
        child: _emailSent ? _buildSuccessUI() : _buildFormUI(),
      ),
    );
  }

  Widget _buildFormUI() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Decorative Header
            Center(
              child: Column(
                children: [
                  Container(
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
                        Icons.lock_reset_rounded,
                        size: 48,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Reset Your Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Enter your email address and we\'ll send you a link to reset your password.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary(context),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            
            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: AppColors.surface(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(
                    color: AppColors.primary(context),
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            
            // Spacer
            const SizedBox(height: 30),
            
            // Reset Button
            Consumer<AppAuthProvider>(
              builder: (context, authProvider, child) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _submitResetRequest,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Send Reset Link',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                );
              },
            ),
            
            // Spacer and Back to Login
            const SizedBox(height: 40),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        // Success Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 50,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Success Ttitle
        const Text(
          'Check Your Email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Success Message
        Text(
          'We\'ve sent a password reset link to:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Email Address
        Text(
          _emailController.text.trim(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 24),
        
        // Instructions
        Text(
          'Click the link in the email to reset your password. '
          'The link will expire in 1 hour for security reasons.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        
        const Spacer(),
        
        // Resend & Back Buttons
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _submitResetRequest,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
                child: const Text('Resend Reset Link'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Login'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}





