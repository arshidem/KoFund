import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/constants/community_types.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/community/providers/community_provider.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class EditCommunityScreen extends StatefulWidget {
  const EditCommunityScreen({super.key});

  @override
  State<EditCommunityScreen> createState() => _EditCommunityScreenState();
}

class _EditCommunityScreenState extends State<EditCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  
  String _selectedType = 'Friends Group';
  Map<String, dynamic> _settings = {
    'notifications': true,
    'financialTransparency': true,
    'memberCanCreateEvents': false,
    'autoArchiveEvents': true,
    'requireApproval': true,
    'isPublic': false,
  };
  
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCommunityData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _loadCommunityData() {
    final communityProvider = context.read<CommunityProvider>();
    final authProvider = context.read<AppAuthProvider>();
    
    final community = communityProvider.currentCommunity;
    final user = authProvider.user;
    
    if (community != null && user != null && !_isInitialized) {
      _nameController.text = community.name;
      _descriptionController.text = community.description ?? '';
      _selectedType = community.type;
      
      if (community.location != null && community.location is Map) {
        final locationMap = community.location as Map<String, dynamic>;
        _locationController.text = locationMap['address'] ?? '';
      }
      
      if (community.settings != null) {
        _settings = Map<String, dynamic>.from(community.settings!);
      }
      
      _isInitialized = true;
      setState(() {});
    }
  }

  Future<void> _updateCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final communityProvider = context.read<CommunityProvider>();
    final authProvider = context.read<AppAuthProvider>();
    
    final community = communityProvider.currentCommunity;
    final user = authProvider.user;

    if (community == null || user == null) {
      SnackbarHelper.showError(context, 'Community not found');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final success = await communityProvider.updateCommunity(
        communityId: community.communityId,
        name: _nameController.text.trim(),
        type: _selectedType,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim().isNotEmpty 
            ? _locationController.text.trim()
            : null,
        settings: _settings,
      );
      if (!mounted) return;
      if (success) {
        SnackbarHelper.showSuccess(context, 'Community updated successfully!');
        Navigator.pop(context);
      } else {
        SnackbarHelper.showError(context, communityProvider.error ?? 'Failed to update community');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
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
          maxLength: maxLength,
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
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: 20,
            ),
          ),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCommunityTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Community Type',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CommunityType.allTypes.map((type) {
            final isSelected = _selectedType == type;
            return ChoiceChip(
              label: Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary(context),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedType = type;
                });
              },
              backgroundColor: AppColors.surface(context),
              selectedColor: AppColors.primary(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                side: BorderSide(
                  color: isSelected 
                      ? AppColors.primary(context) 
                      : AppColors.border(context),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  final communityProvider = context.watch<CommunityProvider>();
  final community = communityProvider.currentCommunity;

  return GradientSheetScaffold(
    title: 'Edit Community',
    actions: [
      if (_isLoading)
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        )
      else
        IconButton(
          onPressed: _updateCommunity,
          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
          tooltip: 'Save Changes',
        ),
    ],
    body: Stack(
        children: [
          // SCROLLABLE CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (communityProvider.isLoading && !_isInitialized)
                    Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary(context),
                      ),
                    )
                  else if (community == null)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Community not found',
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const SizedBox(height: 16),
                    
                    // Community Name
                    _buildInputField(
                      controller: _nameController,
                      label: 'Community Name',
                      hint: 'Enter community name',
                      icon: Icons.group,
                      maxLength: 100,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter community name';
                        }
                        if (value.trim().length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),

                    // Community Description
                    _buildInputField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Describe your community',
                      icon: Icons.description,
                      maxLines: 3,
                      maxLength: 500,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter community description';
                        }
                        if (value.trim().length < 10) {
                          return 'Description must be at least 10 characters';
                        }
                        return null;
                      },
                    ),

                    // Community Type Selector
                    _buildCommunityTypeSelector(),

                    // Location
                    _buildInputField(
                      controller: _locationController,
                      label: 'Location (Optional)',
                      hint: 'e.g., New York, NY',
                      icon: Icons.location_on,
                      maxLength: 100,
                      validator: null,
                    ),

                    const SizedBox(height: 24),

                    // Community Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Community Information',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Community ID', community.communityId),
                          _buildInfoRow('Invite Code', community.inviteCode),
                          _buildInfoRow('Created By', community.createdByName),
                          _buildInfoRow(
                            'Created On',
                            '${community.createdAt.toDate().day}/${community.createdAt.toDate().month}/${community.createdAt.toDate().year}',
                          ),
                          _buildInfoRow('Total Members', '${community.totalMembers}'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 48), 
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
