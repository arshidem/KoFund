import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/widgets/loading_indicator.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onProfileUpdated; // ✅ ADD CALLBACK

  const EditProfileScreen({
    super.key, 
    required this.user,
    this.onProfileUpdated, // ✅ ADD CALLBACK PARAMETER
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
      widget.onProfileUpdated!(); // This can trigger loading state in ProfileScreen
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
  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (profileProvider.isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
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
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue[100],
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.blue[600],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    SnackbarHelper.showInfo(context, 'Photo upload feature coming soon!');
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tap camera icon to update photo',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
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
          decoration: const InputDecoration(
            labelText: 'Display Name *',
            hintText: 'Enter your display name',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your display name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
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
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          readOnly: true,
          enabled: false,
        ),
        const SizedBox(height: 20),

        // Phone Number Field
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter your phone number',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              final phoneRegex = RegExp(r'^[0-9]{10}$');
              if (!phoneRegex.hasMatch(value.trim())) {
                return 'Please enter a valid 10-digit phone number';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Info Card
        Card(
          color: Colors.blue[50],
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your display name will be visible to other community members. Email cannot be changed.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
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
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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