import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import '../providers/app_auth_provider.dart';
import 'splash_screen.dart';
import 'package:kofund/features/community/screens/join_community_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_styles.dart';

class SetPhoneScreen extends StatefulWidget {
  final String? pendingInviteCode;
  const SetPhoneScreen({super.key, this.pendingInviteCode});

  @override
  State<SetPhoneScreen> createState() => _SetPhoneScreenState();
}

class _SetPhoneScreenState extends State<SetPhoneScreen> {
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _cachedInviteCode;
  String? _phoneError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkForPendingInvite();
  }

  Future<void> _checkForPendingInvite() async {
    if (widget.pendingInviteCode != null) {
      _cachedInviteCode = widget.pendingInviteCode;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedInviteCode = prefs.getString('pending_invite_code');

    if (storedInviteCode != null && storedInviteCode.isNotEmpty) {
      _cachedInviteCode = storedInviteCode;
    }
  }

  Future<void> _clearPendingInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_invite_code');
    _cachedInviteCode = null;
  }

  void _navigateToNextScreen() {
    if (_cachedInviteCode != null) {
      _clearPendingInviteCode();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JoinCommunityScreen(inviteCode: _cachedInviteCode),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitPhoneNumber() async {
    setState(() {
      _phoneError = null;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() => _phoneError = 'Phone number is required');
      return;
    }

    // Basic length validation (you can adjust as needed)
    if (phone.length < 8) {
      setState(() => _phoneError = 'Please enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.updateUserPhoneNumber(phone);

      if (success && mounted) {
        _showSuccess('Phone number saved successfully!');

        // Wait a small moment to let the snackbar show before navigating
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        _navigateToNextScreen();
      } else if (mounted) {
        _showError('Failed to save phone number. Please try again.');
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    setState(() => _phoneError = message);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 100,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    final List<TextInputFormatter> formatters = [
      if (inputFormatters != null) ...inputFormatters,
      LengthLimitingTextInputFormatter(maxLength),
    ];

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
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
        prefixIcon: Icon(icon, color: AppColors.primary(context), size: 20),
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
          borderSide: BorderSide(color: AppColors.primary(context), width: 2),
        ),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 12, height: 1.2),
      ),
      onChanged: (_) {
        if (_phoneError != null) {
          setState(() => _phoneError = null);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope equivalent is PopScope in modern Flutter
    return PopScope(
      canPop: false, // Prevent going back until phone number is provided
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showError('Please provide your phone number to continue.');
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppStyles.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary(
                            context,
                          ).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.phone_android,
                          size: 40,
                          color: AppColors.primary(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Complete Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We need your phone number\nto secure your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Phone Input form
                AutofillGroup(
                  child: Column(
                    children: [
                      _buildInputField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        errorText: _phoneError,
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitPhoneNumber,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusFull,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
