import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onProfileUpdated;

  const EditProfileScreen({
    super.key, 
    required this.user,
    this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with current user data
    _nameController.text = widget.user.displayName ?? '';
    _phoneController.text = widget.user.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AppAuthProvider>();

    try {
      // ✅ Show loading in ProfileScreen via callback
      if (widget.onProfileUpdated != null) {
        widget.onProfileUpdated!();
      }

      // ✅ NAVIGATE IMMEDIATELY
      Navigator.pop(context);
      
      // Show loading snackbar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.showInfo(context, 'Updating profile...');
      });

      // ✅ UPDATE IN BACKGROUND
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'displayName': _nameController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty) 
          'phoneNumber': _phoneController.text.trim(),
        'updatedAt': Timestamp.now(),
      });

      // Refresh auth data in background
      await authProvider.refreshUserData();
      if (!mounted) return;

      // ✅ SHOW SUCCESS AFTER UPDATE COMPLETES
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.showSuccess(context, 'Profile updated successfully!');
      });

    } catch (e) {
      debugPrint('Error updating profile: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.showError(context, 'Failed to update profile.');
      });
    }
  }

  // Helper method to get avatar initials
  String _getAvatarInitials() {
    final name = widget.user.displayName ?? widget.user.email;
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return GradientSheetScaffold(
      title: 'Edit Profile',
      actions: [
        if (profileProvider.isLoading)
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary(context),
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(Icons.check, color: AppColors.textPrimary(context)),
            onPressed: _updateProfile,
            tooltip: 'Update Profile',
          ),
      ],
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppStyles.screenPadding,
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Profile Picture Section
              _buildProfilePictureSection(),
              const SizedBox(height: 32),

              // Form Fields
              _buildFormFields(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: AppColors.primary(context).withValues(alpha: 0.2),
          child: Text(
            _getAvatarInitials(),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Avatar based on your name initials',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
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
    bool readOnly = false,
    bool enabled = true,
    int maxLength = 50,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: enabled 
                ? (isDark ? AppColors.surface(context) : Colors.white)
                : (isDark ? AppColors.surface(context).withOpacity(0.5) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            enabled: enabled,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(
              color: enabled ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 15,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 20, right: 12),
                child: Icon(
                  icon,
                  color: enabled ? AppColors.primary(context) : AppColors.textTertiary(context),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              suffixIcon: suffixIcon,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide(
                  color: AppColors.primary(context).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              counterText: '',
            ),
            validator: validator,
            onChanged: (value) {
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    final emailController = TextEditingController(text: widget.user.email);
    return Column(
      children: [
        // Display Name Field
        _buildInputField(
          controller: _nameController,
          label: 'Display Name *',
          hint: 'Enter your display name',
          icon: Icons.person,
          maxLength: 25,
          suffixIcon: _nameController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 20, color: AppColors.textSecondary(context)),
                  onPressed: () {
                    _nameController.clear();
                    if (mounted) setState(() {});
                  },
                )
              : null,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your display name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            if (value.trim().length > 50) {
              return 'Name must be 50 characters or less';
            }
            if (value.trim().contains('  ')) {
              return 'Avoid multiple spaces in name';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Email Field (Read-only)
        _buildInputField(
          controller: emailController,
          label: 'Email Address',
          hint: 'Email Address',
          icon: Icons.email,
          maxLength: 100,
          readOnly: true,
          enabled: false,
        ),
        const SizedBox(height: 20),

        // Phone Number Field
        _buildInputField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          icon: Icons.phone,
          maxLength: 10,
          keyboardType: TextInputType.phone,
          suffixIcon: _phoneController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 20, color: AppColors.textSecondary(context)),
                  onPressed: () {
                    _phoneController.clear();
                    if (mounted) setState(() {});
                  },
                )
              : null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              final ddigitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (ddigitsOnly.length != 10) {
                return 'Please enter a valid 10-digit phone number';
              }
              if (ddigitsOnly.startsWith('0')) {
                return 'Phone number cannot start with 0';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Info Card
        Card(
          color: AppColors.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: AppStyles.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: AppColors.primary(context)),
                    const SizedBox(width: 12),
                    Text(
                      'Input Limits',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Display Name: 2-25 characters\n'
                  '• Email: 100 characters max\n'
                  '• Phone: 10 digits only\n\n'
                  'Your display name will be visible to other community members. '
                  'Email cannot be changed.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}






