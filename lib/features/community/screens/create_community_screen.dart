import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/constants/community_Types.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_styles.dart';
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/community_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kofund/core/services/network_service.dart';

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

  String? _selectedType;
  String? _TypeError;
  bool _isLoading = false;
  
  void _scrollToCommunityTeventType() {
    final BuildContext currentContext = context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    bool hasErrors = false;
    
    setState(() {
      _TypeError = null;
    });

    _formKey.currentState!.validate();

    if (_nameController.text.isEmpty || _nameController.text.length < 3) {
      hasErrors = true;
    }

    if (_locationController.text.isEmpty || _locationController.text.length < 3) {
      hasErrors = true;
    }

    if (_selectedType == null || _selectedType!.isEmpty) {
      setState(() {
        _TypeError = 'Please select a community type';
      });
      hasErrors = true;
    }

    if (hasErrors) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstError();
      });
      return;
    }

    try {
      final hasNetwork = await NetworkService().isConnected;
      if (!mounted) return;
      if (!hasNetwork) {
        if (mounted) {
          SnackbarHelper.showError(
            context, 
            'Internet connection required to create a community. Please check your network and try again.'
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Unable to check network connection');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AppAuthProvider>();
      final communityProvider = context.read<CommunityProvider>();

      if (authProvider.user == null) {
        SnackbarHelper.showError(context, 'User not authenticated');
        return;
      }

      final String adminName = authProvider.getUserDisplayName;

      final success = await communityProvider.createCommunity(
        name: _nameController.text.trim(),
        adminId: authProvider.user!.uid,
        adminEmail: authProvider.user!.email,
        adminName: adminName,
        type: _selectedType!,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim()
            : 'Community for ${_nameController.text.trim()}',
        location: _locationController.text.trim(),
      );

      if (success && communityProvider.currentCommunity != null) {
        final community = communityProvider.currentCommunity!;
        
        await authProvider.setUserAsCommunityAdmin(
          communityId: community.communityId,
          communityName: community.name,
        );

        await authProvider.refreshUserData();
        if (!mounted) return;

        if (mounted) {
          SnackbarHelper.showSuccess(
            context, 
            'Community "${_nameController.text.trim()}" created successfully!'
          );
          context.go(RouteNames.communityDashboard);
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

  void _scrollToFirstError() {
    final context = _formKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int maxLength = 100,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    final List<TextInputFormatter> formatters = [
      if (inputFormatters != null) ...inputFormatters,
      LengthLimitingTextInputFormatter(maxLength),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = maxLines > 1 ? 24.0 : 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface(context) : Colors.white,
            borderRadius: BorderRadius.circular(radius),
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
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            inputFormatters: formatters,
            validator: validator,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: isRequired ? '$label *' : label,
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 15,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 20, right: 12, bottom: maxLines > 1 ? 40 : 0),
                child: Icon(
                  icon,
                  color: AppColors.primary(context),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              filled: false,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: maxLines == 1 ? 18 : 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(
                  color: AppColors.primary(context).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityTeventTypeDropdown() {
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
          child: DropdownButtonFormField<String?>(
            value: _selectedType,
            isExpanded: true,
            icon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.primary(context),
                size: 26,
              ),
            ),
            dropdownColor: AppColors.card(context),
            decoration: InputDecoration(
              hintText: 'Community Category *',
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 15,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 20, right: 12),
                child: Icon(
                  Icons.category_outlined,
                  color: AppColors.primary(context),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
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
                vertical: 16,
              ),
            ),
            items: CommunityType.allTypes.map((type) {
              return DropdownMenuItem<String?>(
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value;
                _TypeError = null;
              });
            },
          ),
        ),
        if (_TypeError != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 6),
            child: Text(
              _TypeError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Curved Decorative Background Shapes (Teal/Mint overlays)
          Positioned(
            top: -180,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -140,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          // Brand Logo & Text
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(context),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary(context).withOpacity(0.25),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/logos/KoFund.svg',
                                      height: 44,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.8,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Ko',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Fund',
                                        style: TextStyle(
                                          color: AppColors.primary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Header Typography
                          Center(
                            child: Text(
                              'Create Community',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Start building your community and invite members to join',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Form(
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            key: _formKey,
                            child: Column(
                              children: [
                                // Community Name
                                _buildInputField(
                                  controller: _nameController,
                                  label: 'Community Name',
                                  icon: Icons.group_outlined,
                                  hint: 'e.g., Tech Enthusiasts Club, Fitness Group',
                                  isRequired: true,
                                ),
                                const SizedBox(height: 14),

                                // Category Dropdown
                                _buildCommunityTeventTypeDropdown(),

                                // Description
                                _buildInputField(
                                  controller: _descriptionController,
                                  label: 'Description',
                                  icon: Icons.description_outlined,
                                  hint: 'Describe purpose, goals, rules, or activities...',
                                  maxLines: 3,
                                  maxLength: 200,
                                ),
                                const SizedBox(height: 14),

                                // Location
                                _buildInputField(
                                  controller: _locationController,
                                  label: 'Location',
                                  icon: Icons.location_on_outlined,
                                  hint: 'e.g., Kochi, Chennai, Bangalore',
                                  isRequired: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter location';
                                    }
                                    if (value.length < 3) {
                                      return 'Location must be at least 3 characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Create Button
                                FutureBuilder<bool>(
                                  future: NetworkService().isConnected,
                                  builder: (context, snapshot) {
                                    final bool isOnline = snapshot.data ?? true;
                                    
                                    return StreamBuilder<bool>(
                                      stream: NetworkService().onConnectionChanged,
                                      builder: (context, streamSnapshot) {
                                        final bool currentIsOnline = streamSnapshot.data ?? isOnline;
                                        final bool isDisabled = _isLoading || !currentIsOnline;
                                        
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Container(
                                              height: 56,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(100),
                                                boxShadow: [
                                                  if (!isDisabled)
                                                    BoxShadow(
                                                      color: AppColors.primary(context).withOpacity(0.25),
                                                      blurRadius: 16,
                                                      offset: const Offset(0, 6),
                                                    ),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                onPressed: isDisabled ? null : _createCommunity,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary(context),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(100),
                                                  ),
                                                ),
                                                child: _isLoading
                                                    ? const SizedBox(
                                                        height: 24,
                                                        width: 24,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            currentIsOnline ? Icons.group_add_rounded : Icons.wifi_off_rounded,
                                                            size: 20,
                                                          ),
                                                          const SizedBox(width: 10),
                                                          Text(
                                                            currentIsOnline ? 'Create Community' : 'Offline',
                                                            style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                            if (!currentIsOnline)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8, left: 16),
                                                child: Row(
                                                  children: const [
                                                    Icon(
                                                      Icons.info_outline_rounded,
                                                      size: 14,
                                                      color: Colors.redAccent,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Internet connection required',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.redAccent,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),

                                const SizedBox(height: 18),

                                // OR Divider
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: AppColors.border(context),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(
                                          color: AppColors.textTertiary(context),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: AppColors.border(context),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                // Join Existing Community Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: AppColors.primary(context),
                                        width: 1.5,
                                      ),
                                      backgroundColor: isDark ? AppColors.surface(context) : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_rounded,
                                          color: AppColors.primary(context),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Join Existing Community',
                                          style: TextStyle(
                                            color: AppColors.primary(context),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Features Info Card
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.withOpacity(0.12),
                                        Colors.blue.withOpacity(0.04),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
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
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '• Auto-generated unique invite code\n'
                                                '• You become the community admin\n'
                                                '• Invite members with the generated code\n'
                                                '• Manage events and members\n'
                                                '• Choose from ${CommunityType.allTypes.length} community categories',
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
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
