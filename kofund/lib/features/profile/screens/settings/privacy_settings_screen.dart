import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:flutter/services.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _showDetailedProfile = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentSettings();
    });
  }

  void _loadCurrentSettings() {
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    if (user != null) {
      setState(() {
        _showDetailedProfile = user.showDetailedProfile ?? false;
        _initialized = true;
      });
    }
  }

  Future<void> _updatePrivacySetting(bool newValue) async {
    final profileProvider = context.read<ProfileProvider>();
    
    try {
      final success = await profileProvider.updatePrivacySettings(newValue);
      
      if (success) {
        setState(() => _showDetailedProfile = newValue);
        SnackbarHelper.showSuccess(context, 'Privacy settings updated!');
        
        // Refresh the user data in AppAuthProvider
        await context.read<AppAuthProvider>().refreshUserData();
      } else {
        SnackbarHelper.showError(context, profileProvider.error ?? 'Failed to update privacy settings');
        setState(() => _showDetailedProfile = !newValue);
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to update privacy settings: $e');
      setState(() => _showDetailedProfile = !newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final user = authProvider.user;

    if (user == null || !_initialized) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text(
            'Privacy Settings',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
          toolbarHeight: 80, // Set your desired height here (default is 56)

        title: Text(
          'Profile Privacy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: profileProvider.isLoading ? null : () => Navigator.pop(context),
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
        actions: [
          if (profileProvider.isLoading)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Privacy Toggle Card
              Card(
                elevation: 2,
                color: AppColors.card(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          'Show Detailed Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          'Allow others to see your contributions and program details',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        value: _showDetailedProfile,
                        activeColor: AppColors.primary(context),
                        onChanged: profileProvider.isLoading ? null : (value) {
                          _updatePrivacySetting(value);
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Visual Indicator
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _showDetailedProfile 
                              ? AppColors.success(context).withOpacity(0.1)
                              : AppColors.info(context).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showDetailedProfile 
                                ? AppColors.success(context)
                                : AppColors.info(context),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showDetailedProfile ? Icons.visibility : Icons.visibility_off,
                              color: _showDetailedProfile 
                                  ? AppColors.success(context)
                                  : AppColors.info(context),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _showDetailedProfile 
                                  ? 'Others can see your contributions and program details'
                                  : 'Others can only see your basic profile information',
                                style: TextStyle(
                                  color: _showDetailedProfile 
                                      ? AppColors.success(context)
                                      : AppColors.info(context),
                                  fontWeight: FontWeight.w500,
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
              
              const SizedBox(height: 24),
              
              // Information Card
              Card(
                color: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What others can see:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Always visible items
                      _buildVisibilityItem('👤', 'Your name', true, context),
                      _buildVisibilityItem('📧', 'Your email', true, context),
                      _buildVisibilityItem('📱', 'Your phone number', true, context),
                      _buildVisibilityItem('🎯', 'Program participation count', true, context),
                      _buildVisibilityItem('👥', 'Your role in community', true, context),
                      _buildVisibilityItem('📅', 'Join date', true, context),
                      
                      const SizedBox(height: 8),
                      Divider(color: AppColors.border(context)),
                      const SizedBox(height: 8),
                      
                      // Only visible when toggle is ON
                      _buildVisibilityItem('💰', 'Contribution amounts', _showDetailedProfile, context),
                      _buildVisibilityItem('📝', 'Which specific programs you joined', _showDetailedProfile, context),
                      _buildVisibilityItem('📊', 'Your contribution history', _showDetailedProfile, context),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Admin Note
              if (user.role == 'admin') ...[
                Card(
                  color: AppColors.surface(context).withOpacity(1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings, 
                          color: AppColors.warning(context), 
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'As an admin, you can always see all member details regardless of their privacy settings.',
                            style: TextStyle(
                              fontSize: 12, 
                              color: AppColors.warning(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              if (profileProvider.isLoading) ...[
                const SizedBox(height: 20),
                CircularProgressIndicator(color: AppColors.primary(context)),
                const SizedBox(height: 10),
                Text(
                  'Updating privacy settings...',
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityItem(String emoji, String text, bool isVisible, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          Icon(
            isVisible ? Icons.check_circle : Icons.remove_circle,
            color: isVisible ? AppColors.success(context) : AppColors.textSecondary(context),
            size: 20,
          ),
        ],
      ),
    );
  }
}