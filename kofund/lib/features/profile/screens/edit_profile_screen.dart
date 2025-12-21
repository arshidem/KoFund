import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:kofund/core/constants/app_colors.dart';
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

      // ✅ SHOW SUCCESS AFTER UPDATE COMPLETES
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.showSuccess(context, 'Profile updated successfully!');
      });

    } catch (e) {
      print('Error updating profile: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.showError(context, 'Failed to update profile.');
      });
    }
  }

  // Helper method to get avatar initials
  String _getAvatarInitials() {
    final name = widget.user.displayName ?? widget.user.email ?? '?';
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.background(context),
     appBar: AppBar(
  title: Text(
    'Edit Profile',
    style: TextStyle(color: Colors.white), // White text
  ),
  centerTitle: true,
  leading: IconButton(
    icon: Icon(
      Icons.arrow_back,
      color: Colors.white, // White back icon
    ),
    onPressed: () => Navigator.pop(context),
  ),
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white, // This sets all icons to white
  elevation: 0,
  systemOverlayStyle: const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ),
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
    ),
  ),
  actions: [
    if (profileProvider.isLoading)
      Container(
        margin: const EdgeInsets.only(right: 16),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white, // White loading indicator
          ),
        ),
      ),
  ],
),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture Section
              _buildProfilePictureSection(),
              const SizedBox(height: 32),

              // Form Fields
              _buildFormFields(),
              const SizedBox(height: 32),

              // Update Button
              _buildUpdateButton(profileProvider),
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
          backgroundColor: AppColors.primary(context).withOpacity(0.2),
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

  Widget _buildFormFields() {
    return Column(
      children: [
        // Display Name Field
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Display Name *',
            hintText: 'Enter your display name',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: AppColors.card(context),
            counterText: '${_nameController.text.length}/25',
            suffixIcon: _nameController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20, color: AppColors.textSecondary(context)),
                    onPressed: () {
                      _nameController.clear();
                      if (mounted) setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: TextStyle(color: AppColors.textPrimary(context)),
          maxLength: 25,
          onChanged: (value) {
            if (mounted) setState(() {});
          },
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
            // Check for excessive spaces
            if (value.trim().contains('  ')) {
              return 'Avoid multiple spaces in name';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Email Field (Read-only)
        TextFormField(
          initialValue: widget.user.email,
          decoration: InputDecoration(
            labelText: 'Email Address',
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
            filled: true,
            fillColor: AppColors.card(context).withOpacity(0.5),
            counterText: '${widget.user.email?.length ?? 0}/100',
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: TextStyle(color: AppColors.textSecondary(context)),
          readOnly: true,
          enabled: false,
          maxLength: 100,
        ),
        const SizedBox(height: 20),

        // Phone Number Field
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter your phone number',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: AppColors.card(context),
            counterText: '${_phoneController.text.length}/10',
            suffixIcon: _phoneController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20, color: AppColors.textSecondary(context)),
                    onPressed: () {
                      _phoneController.clear();
                      if (mounted) setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: TextStyle(color: AppColors.textPrimary(context)),
          maxLength: 10,
          keyboardType: TextInputType.phone,
          onChanged: (value) {
            if (mounted) setState(() {});
          },
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              // Remove any non-digit characters for validation
              final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
              
              if (digitsOnly.length != 10) {
                return 'Please enter a valid 10-digit phone number';
              }
              
              // Check if it's a realistic phone number (doesn't start with 0)
              if (digitsOnly.startsWith('0')) {
                return 'Phone number cannot start with 0';
              }
            }
            return null;
          },
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly, // Only allow digits
          ],
        ),
        const SizedBox(height: 20),

        // Info Card
        Card(
          color: AppColors.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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

  Widget _buildUpdateButton(ProfileProvider profileProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: profileProvider.isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Rounded button corners
          ),
        ),
        child: profileProvider.isLoading
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
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text(
                    'Update Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}