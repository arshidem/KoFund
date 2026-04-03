import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/widgets/network_aware_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordChanged = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AppAuthProvider>();
    final success = await authProvider.changePassword(
      currentPassword: _currentPasswordController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _passwordChanged = true;
      });
      
      // Clear form
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Change Password',
      body: Padding(
        padding: AppStyles.screenPadding,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _passwordChanged ? _buildSuccessUI() : _buildFormUI(),
        ),
      ),
    );
  }

  Widget _buildFormUI() {
    final authProvider = context.watch<AppAuthProvider>();

    if (authProvider.isGoogleOnlyUser) {
      return _buildGoogleAuthMessage();
    }

    return SingleChildScrollView(
      key: const ValueKey('form_ui'),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Your Password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your current password and set a new one to keep your account secure.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(context),
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 32),
            
            _buildInputField(
              controller: _currentPasswordController,
              label: 'Current Password',
              hint: 'Enter your current password',
              icon: Icons.lock_outline,
              obscureText: _obscureCurrentPassword,
              onToggleVisibility: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Current password is required';
                }
                return null;
              },
            ),
            
            _buildInputField(
              controller: _newPasswordController,
              label: 'New Password',
              hint: 'Enter a strong new password',
              icon: Icons.lock_reset_rounded,
              obscureText: _obscureNewPassword,
              onToggleVisibility: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              validator: _validatePassword,
            ),
            
            _buildInputField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              hint: 'Re-enter your new password',
              icon: Icons.check_circle_outline_rounded,
              obscureText: _obscureConfirmPassword,
              onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              validator: _validateConfirmPassword,
              isLast: true,
            ),
            
            // Password Requirements Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: AppStyles.radiusMedium,
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.primary(context)),
                      const SizedBox(width: 8),
                      Text(
                        'Password Requirements',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRequirementItem('Minimum 6 characters long'),
                  const SizedBox(height: 6),
                  _buildRequirementItem('Unique from your current password'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            Consumer<AppAuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  children: [
                    NetworkAwareButton(
                      label: 'Update Password',
                      icon: Icons.security_rounded,
                      isLoading: authProvider.isLoading,
                      onPressed: _changePassword,
                    ),
                    
                    if (authProvider.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error(context).withValues(alpha: 0.1),
                          borderRadius: AppStyles.radiusMedium,
                          border: Border.all(color: AppColors.error(context).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.error(context), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authProvider.error!,
                                style: TextStyle(
                                  color: AppColors.error(context),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleAuthMessage() {
    return Column(
      key: const ValueKey('google_auth_ui'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/logos/google_logo.png',
            width: 60,
            height: 60,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.account_circle_rounded,
              size: 60,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Google Account',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'You are currently signed in with Google. Your password is managed by your Google Account settings and cannot be changed from within this app.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Settings'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppColors.primary(context),
              side: BorderSide(color: AppColors.primary(context)),
              shape: RoundedRectangleBorder(
                borderRadius: AppStyles.radiusMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (_) => isLast ? _changePassword() : null,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
            floatingLabelStyle: TextStyle(
              color: AppColors.primary(context),
              fontWeight: FontWeight.w600,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context).withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary(context),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textSecondary(context).withValues(alpha: 0.6),
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: AppColors.card(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
              borderSide: BorderSide(color: AppColors.primary(context), width: 1.5),
            ),
            errorStyle: const TextStyle(height: 0.8),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRequirementItem(String text) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success(context).withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessUI() {
    return Column(
      key: const ValueKey('success_ui'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success(context).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: AppColors.success(context),
            size: 60,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Password Updated!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Your security credentials have been successfully updated. You can now use your new password to sign in.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.info(context).withValues(alpha: 0.05),
            borderRadius: AppStyles.radiusMedium,
            border: Border.all(color: AppColors.info(context).withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.security_update_good_rounded, color: AppColors.info(context), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Other logged-in sessions may require a re-authentication for security.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.info(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: AppStyles.radiusMedium,
              ),
              elevation: 0,
            ),
            child: const Text(
              'Back to Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
