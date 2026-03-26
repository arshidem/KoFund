import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/constants/community_types.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/community_provider.dart';
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
  String? _typeError; // Add this with your other error variables
  bool _isLoading = false;
  
void _scrollToCommunityType() {
  final BuildContext? currentContext = context;
  if (currentContext != null) {
    // You might need to wrap the dropdown in a KeyedSubtree
    // or find another way to scroll to it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }
}
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

Future<void> _createCommunity() async {
  // 1. VALIDATE ALL FIELDS AND SHOW ALL ERRORS AT ONCE
  bool hasErrors = false;
  
  // Clear all previous errors
  setState(() {
    _typeError = null;
  });

  // Force validate all fields
  _formKey.currentState!.validate();

  // Check community name
  if (_nameController.text.isEmpty || _nameController.text.length < 3) {
    hasErrors = true;
  }

  // Check location
  if (_locationController.text.isEmpty || _locationController.text.length < 3) {
    hasErrors = true;
  }

  // Check community type
  if (_selectedType == null || _selectedType!.isEmpty) {
    setState(() {
      _typeError = 'Please select a community type';
    });
    hasErrors = true;
  }

  // If any errors exist, stop here
  if (hasErrors) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFirstError();
    });
    return;
  }

  // 2. Check network AFTER form validation passes
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

  // 3. Only set loading state AFTER network check passes
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
      adminEmail: authProvider.user!.email ?? '',
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

// Add this method to scroll to first error
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
  required String hint, // ⭐ KEEP HINT for description
  bool obscureText = false,
  bool showObscureToggle = false,
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

  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    maxLines: maxLines,
    inputFormatters: formatters,
    validator: validator,
    style: TextStyle(
      color: AppColors.textPrimary(context),
      fontSize: 14,
    ),
    decoration: InputDecoration(
      labelText: isRequired ? '$label *' : label, // ⭐ FLOATING LABEL
      labelStyle: TextStyle(
        color: AppColors.textSecondary(context),
        fontSize: 14,
      ),
      floatingLabelStyle: TextStyle(
        color: AppColors.primary(context),
        fontWeight: FontWeight.w600,
      ),
      hintText: hint, // ⭐ DESCRIPTIVE HINT
      hintStyle: TextStyle(
        color: AppColors.textSecondary(context),
        fontSize: maxLines > 1 ? 13 : 14, // Smaller for multiline
      ),
      prefixIcon: Icon(
        icon,
        color: AppColors.primary(context),
        size: 20,
      ),
      filled: true,
      fillColor: AppColors.surface(context),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: maxLines == 1 ? 18 : 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        borderSide: BorderSide(color: AppColors.border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        borderSide: BorderSide(color: AppColors.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        borderSide: BorderSide(
          color: AppColors.primary(context),
          width: 2,
        ),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(
        fontSize: 12,
        height: 1.2,
      ),
    ),
  );
}

Widget _buildCommunityTypeDropdown() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ⭐ NO LABEL - Just the dropdown with hint
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: _typeError != null 
                ? Colors.red.withValues(alpha: 0.8) 
                : AppColors.border(context),
            width: _typeError != null ? 1.5 : 1,
          ),
          color: _typeError != null 
              ? Colors.red.withValues(alpha: 0.03) 
              : AppColors.surface(context),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _selectedType,
            isExpanded: true,
            icon: Icon(
              Icons.arrow_drop_down,
              color: _typeError != null 
                  ? Colors.red 
                  : AppColors.textSecondary(context),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            hint: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                'Select community type *',
                style: TextStyle(
                  color: _typeError != null 
                      ? Colors.red.withValues(alpha: 0.7) 
                      : AppColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),
            ),
            items: CommunityType.allTypes.map((type) {
              return DropdownMenuItem<String?>(
                value: type,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary(context).withValues(alpha: 0.1),
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
              setState(() {
                _selectedType = value;
                _typeError = null; // Clear error on selection
              });
            },
          ),
        ),
      ),
      
      // ⭐ ERROR MESSAGE (appears below when there's an error)
      if (_typeError != null)
        Padding(
          padding: const EdgeInsets.only(left: 6, top: 4),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                _typeError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
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
  toolbarHeight: 80,
  title: const Text(
    'Create Community',
    style: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  centerTitle: true,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => Navigator.pop(context),
  ),
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white,
  elevation: 0,
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background(context),
    systemNavigationBarIconBrightness:
        Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
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
                            color: AppColors.primary(context).withValues(alpha: 0.3),
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
// Community Name - Clear with hint
_buildInputField(
  controller: _nameController,
  label: 'Community Name',
  icon: Icons.group,
  hint: 'e.g., Tech Enthusiasts Club, Fitness Group',
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
              const SizedBox(height: 12),

                      _buildCommunityTypeDropdown(),

              const SizedBox(height: 12),

// Description - Detailed hint
_buildInputField(
  controller: _descriptionController,
  label: 'Description',
  icon: Icons.description,
  hint: 'Describe purpose, goals, rules, or activities...',
  maxLines: 3,
  maxLength: 200,
),
              const SizedBox(height: 12),


// Location - Helpful hint
_buildInputField(
  controller: _locationController,
  label: 'Location',
  icon: Icons.location_on,
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

                      const SizedBox(height: 16),

                      // Info Card
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(24),

    // ✅ Same soft gradient pattern
    gradient: LinearGradient(
      colors: [
        Colors.blue.withValues(alpha: 0.15),
        Colors.blue.withValues(alpha: 0.05),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),

    // ✅ Same border style
    border: Border.all(
      color: Colors.blue.withValues(alpha: 0.25),
    ),

    // ✅ Same soft shadow
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
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

// Replace your StreamBuilder with this:
FutureBuilder<bool>(
  future: NetworkService().isConnected, // Initial check
  builder: (context, snapshot) {
    final bool isOnline = snapshot.data ?? true;
    
    return StreamBuilder<bool>(
      stream: NetworkService().onConnectionChanged,
      builder: (context, streamSnapshot) {
        // Use stream data if available, otherwise use future data
        final bool currentIsOnline = streamSnapshot.data ?? isOnline;
        final bool isDisabled = _isLoading || !currentIsOnline;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isDisabled ? null : _createCommunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary(context).withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            currentIsOnline ? Icons.group_add : Icons.wifi_off,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            currentIsOnline ? 'Create Community' : 'Offline',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            if (!currentIsOnline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 6),
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
        borderRadius: BorderRadius.circular(28),
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
