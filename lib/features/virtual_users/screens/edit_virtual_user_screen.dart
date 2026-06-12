// lib/features/virtual_users/screens/edit_virtual_user_screen.dart
// FIXED VERSION

import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/auth/models/user_model.dart';
// ❌ REMOVE UNUSED IMPORT: import 'package:kofund/features/auth/providers/app_auth_provider.dart';
// ❌ REMOVE UNUSED IMPORT: import 'package:kofund/core/services/virtual_user_service.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/virtual_users/providers/virtual_user_provider.dart';
import 'package:kofund/core/services/network_service.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class EditVirtualUserScreen extends StatefulWidget {
  final UserModel virtualUser;
  
  const EditVirtualUserScreen({
    super.key,
    required this.virtualUser,
  });

  @override
  State<EditVirtualUserScreen> createState() => _EditVirtualUserScreenState();
}

class _EditVirtualUserScreenState extends State<EditVirtualUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.virtualUser.displayName ?? '';
    _phoneNumberController.text = widget.virtualUser.phoneNumber ?? '';
    
    // Listen for changes
    _displayNameController.addListener(_checkForChanges);
    _phoneNumberController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _displayNameController.text != (widget.virtualUser.displayName ?? '') ||
                   _phoneNumberController.text != (widget.virtualUser.phoneNumber ?? '');
    });
  }

  Future<void> _updateVirtualUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get the provider from context
      final virtualUserProvider = Provider.of<VirtualUserProvider>(context, listen: false);
      
      final success = await virtualUserProvider.editVirtualUser(
        userId: widget.virtualUser.uid,
        displayName: _displayNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isEmpty 
            ? null 
            : _phoneNumberController.text.trim(),
        email: widget.virtualUser.email, // Keep original email
      );
      
      if (success) {
        // Show success message
        if (mounted) {
          SnackbarHelper.showSuccess(
            context, 
            'Virtual user updated successfully'
          );
          Navigator.pop(context, true);
        }
      } else {
        final error = virtualUserProvider.editError;
        if (mounted && error != null) {
          SnackbarHelper.showError(
            context, 
            error
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context, 
          'Failed to update virtual user: $e'
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Edit Virtual User',
      actions: [
        StatefulBuilder(
          builder: (context, setState) {
            return _isLoading
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StreamBuilder<bool>(
                      stream: NetworkService().onConnectionChanged,
                      initialData: true,
                      builder: (context, snapshot) {
                        final bool isOnline = snapshot.data ?? true;
                        
                        return IconButton(
                          icon: isOnline
                              ? Icon(Icons.check, color: AppColors.textPrimary(context), size: 26)
                              : Icon(Icons.wifi_off, color: AppColors.textPrimary(context).withValues(alpha: 0.7), size: 26),
                          tooltip: isOnline 
                              ? 'Save Changes'
                              : 'Offline - No Connection',
                          onPressed: isOnline && _hasChanges && !_isLoading ? _updateVirtualUser : null,
                        );
                      },
                    ),
                  );
          },
        ),
      ],
      body: SingleChildScrollView(
          padding: AppStyles.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Virtual User Info Card
                Container(
                  width: double.infinity,
                  padding: AppStyles.screenPadding,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    // ✅ FIXED: Replace .withValues(alpha: ) with Color.fromRGBO()
                    color: AppColors.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: AppColors.primary(context), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Virtual User Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (widget.virtualUser.createdByName != null && widget.virtualUser.createdByName!.isNotEmpty)
                        _buildInfoItem(
                          'Created By Admin',
                          widget.virtualUser.createdByName!,
                          Icons.person_add,
                        ),
                      
                      if (widget.virtualUser.createdAt != null)
                        _buildInfoItem(
                          'Created On',
                          _formatDateFromTimestamp(widget.virtualUser.createdAt),
                          Icons.calendar_today,
                        ),
                    ],
                  ),
                ),
                
                // Edit Form Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Display Name Field
                      _buildFormField(
                        controller: _displayNameController,
                        label: 'Display Name',
                        hintText: 'Enter display name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Display name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Phone Number Field
                      _buildFormField(
                        controller: _phoneNumberController,
                        label: 'Phone Number (Optional)',
                        hintText: 'Enter phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final phoneRegex = RegExp(r'^[0-9]{10}$');
                            if (!phoneRegex.hasMatch(value.trim())) {
                              return 'Enter a valid 10-digit phone number';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Note about virtual users
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // ✅ FIXED: Replace .withValues(alpha: ) with Color.fromRGBO()
                          color: AppColors.primary(context).withValues(alpha: 0.05), // Keep this one as it's already a Color property
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info, size: 18, color: AppColors.primary(context)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Virtual users don\'t have app access. Their information is managed by community admins.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary(context),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary(context).withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface(context) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
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
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 15,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 20, right: 12),
                child: Icon(
                  icon,
                  color: AppColors.primary(context),
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              filled: false,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  String _formatDateFromTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = _getMonth(date.month);
    final year = date.year;
    return '$day $month $year';
  }

  String _getMonth(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}





