import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/constants/community_types.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/community_provider.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  String _selectedType = CommunityType.apartment;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AppAuthProvider>();
    final communityProvider = context.read<CommunityProvider>();

    if (authProvider.user == null) {
      SnackbarHelper.showError(context, 'User not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String adminName = authProvider.getUserDisplayName;

      final success = await communityProvider.createCommunity(
        name: _nameController.text.trim(),
        adminId: authProvider.user!.uid,
        adminEmail: authProvider.user!.email ?? '',
        adminName: adminName,
        type: _selectedType,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim()
            : 'Community for ${_nameController.text.trim()}',
        location: _locationController.text.trim().isNotEmpty 
            ? _locationController.text.trim()
            : null,
      );

      if (success && communityProvider.currentCommunity != null) {
        final community = communityProvider.currentCommunity!;
        
        await authProvider.setUserAsCommunityAdmin(
          communityId: community.communityId,
          communityName: community.name,
        );

        await authProvider.refreshUserData();

        if (mounted) {
          SnackbarHelper.showSuccess(
            context, 
            'Community "${_nameController.text.trim()}" created successfully!'
          );
          Navigator.pushReplacementNamed(context, RouteNames.communityDashboard);
        }
      } else {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            communityProvider.error ?? 'Failed to create community',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error creating community: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int maxLength = 100,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
              fontSize: 14,
            ),
            children: isRequired
                ? [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLines == 1 ? maxLength : null,
          inputFormatters: [
            if (maxLines == 1) LengthLimitingTextInputFormatter(maxLength),
          ],
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary(context),
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primary(context),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: maxLines == 1 ? 20 : 16,
              bottom: maxLines == 1 ? 20 : 16,
            ),
            counterText: '',
          ),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCommunityTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Community Type',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
              fontSize: 14,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context)),
            color: AppColors.surface(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppColors.textSecondary(context),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              items: CommunityType.allTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              CommunityType.getIcon(type),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CommunityType.getDescription(type),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Create Community'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ✅ Logo Header (similar to LoginScreen)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                child: Column(
                  children: [
                    // Logo with rounded background
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(context).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/logos/KoFund.png', // Your logo path
                            height: 70,
                            width: 70,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create Community',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Start building your community and invite members to join',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Rest of your form fields remain exactly the same...
                    _buildInputField(
                      controller: _nameController,
                      label: 'Community Name',
                      hint: 'Enter community name',
                      icon: Icons.group,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a community name';
                        }
                        if (value.length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    // ... rest of your existing code

                      // Community Type Dropdown
                      _buildCommunityTypeDropdown(),

                      // Description
                      _buildInputField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Describe your community purpose, goals, or rules...',
                        icon: Icons.description,
                        maxLines: 3,
                        maxLength: 200,
                      ),

                      // Location
                      _buildInputField(
                        controller: _locationController,
                        label: 'Location',
                        hint: 'e.g., Kochi, Chennai, Bangalore',
                        icon: Icons.location_on,
                        maxLength: 50,
                      ),

                      const SizedBox(height: 16),

                      // Info Card
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(24),

    // ✅ Same soft gradient pattern
    gradient: LinearGradient(
      colors: [
        Colors.blue.withOpacity(0.15),
        Colors.blue.withOpacity(0.05),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),

    // ✅ Same border style
    border: Border.all(
      color: Colors.blue.withOpacity(0.25),
    ),

    // ✅ Same soft shadow
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Colors.blue.shade700,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community Features',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Auto-generated unique invite code\n'
                '• You become the community admin\n'
                '• Invite members with the generated code\n'
                '• Manage programs and members\n'
                '• Choose from ${CommunityType.allTypes.length} community types',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade800,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),


                      const SizedBox(height: 32),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createCommunity,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle_outline, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Create Community',
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

                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.border(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: AppColors.surface(context),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),

                      const SizedBox(height: 20),

              SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () => Navigator.pop(context),
    icon: Icon(
      Icons.search,
      color: AppColors.primary(context),
    ),
    label: Text(
      'Join Existing Community',
      style: TextStyle(
        color: AppColors.primary(context),
      ),
    ),
    style: OutlinedButton.styleFrom(
      side: BorderSide(
        color: AppColors.primary(context),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
),


                      const SizedBox(height: 20),
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