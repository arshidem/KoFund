import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/constants/community_types.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/community/providers/community_provider.dart';
import 'package:kofund/core/services/network_service.dart';
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
  bool _isOnline = true;
  late final NetworkService _networkService;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _networkService = NetworkService();
    
    _networkService.onConnectionChanged.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
      }
    });
    
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
    final double borderRadius = maxLines > 1 ? 24.0 : AppDimensions.radiusFull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            labelStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textTertiary(context),
              fontSize: 15,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.primary(context),
                size: 18,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: AppColors.primary(context),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCommunityTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Community Category',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: AppColors.border(context),
            ),
            color: AppColors.surface(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.primary(context),
              ),
              dropdownColor: AppColors.card(context),
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              items: CommunityType.allTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        CommunityType.getMaterialIcon(type),
                        size: 20,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        type,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
        const SizedBox(height: 24),
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
      title: 'Settings',
      actions: [
        if (!_isOnline)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 20),
          ),
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
            onPressed: _isOnline ? _updateCommunity : null,
            icon: Icon(
              Icons.check_rounded, 
              color: _isOnline ? Colors.white : Colors.white.withValues(alpha: 0.5), 
              size: 28
            ),
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

                    _buildCommunityTypeDropdown(),

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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppColors.primary(context), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Community Metadata',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary(context),
                                  fontSize: 16,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          _buildInfoRow('Community ID', community.communityId),
                          const SizedBox(height: 8),
                          _buildInfoRow('Invite Code', community.inviteCode),
                          const SizedBox(height: 8),
                          _buildInfoRow('Created By', community.createdByName),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Created Date',
                            '${community.createdAt.toDate().day}/${community.createdAt.toDate().month}/${community.createdAt.toDate().year}',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Member Count', '${community.totalMembers} Members'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 80), 
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
