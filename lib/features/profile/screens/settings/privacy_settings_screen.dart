import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/widgets/premium_switch.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

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
    final authProvider = context.read<AppAuthProvider>();

    try {
      final success = await profileProvider.updatePrivacySettings(newValue);

      if (!mounted) return;

      if (success) {
        setState(() => _showDetailedProfile = newValue);
        SnackbarHelper.showSuccess(context, 'Privacy settings updated!');

        // Refresh the user data in AppAuthProvider using the captured provider
        await authProvider.refreshUserData();
        if (!mounted) return;
      } else {
        SnackbarHelper.showError(context, profileProvider.error ?? 'Failed to update privacy settings');
        setState(() => _showDetailedProfile = !newValue);
      }
    } catch (e) {
      if (!mounted) return;
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
      return GradientSheetScaffold(
        title: 'Privacy Settings',
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GradientSheetScaffold(
      title: 'Profile Privacy',
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Profile Visibility'),
            _buildSettingsGroup(
              children: [
                _buildPrivacyToggle(profileProvider),
                _buildItemDivider(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _showDetailedProfile
                          ? AppColors.primary(context).withValues(alpha: 0.1)
                          : AppColors.info(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showDetailedProfile
                            ? AppColors.primary(context)
                            : AppColors.info(context).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showDetailedProfile
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: _showDetailedProfile
                              ? AppColors.primary(context)
                              : AppColors.info(context),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _showDetailedProfile
                                ? 'Others can see your contributions and event details'
                                : 'Others can only see your basic profile information',
                            style: TextStyle(
                              fontSize: 12,
                              color: _showDetailedProfile
                                  ? AppColors.primary(context)
                                  : AppColors.info(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('What others can see'),
            _buildSettingsGroup(
              children: [
                _buildVisibilityItem(Icons.person_rounded, 'Your name', true),
                _buildItemDivider(),
                _buildVisibilityItem(Icons.email_rounded, 'Your email', true),
                _buildItemDivider(),
                _buildVisibilityItem(Icons.smartphone_rounded, 'Your phone number', true),
                _buildItemDivider(),
                _buildVisibilityItem(Icons.monetization_on_rounded, 'Contribution amounts', _showDetailedProfile),
                _buildItemDivider(),
                _buildVisibilityItem(Icons.assessment_rounded, 'Contribution history', _showDetailedProfile),
              ],
            ),
            
            if (user.role == 'admin') ...[
              const SizedBox(height: 32),
              _buildSectionHeader('Administrator Note'),
              _buildSettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'As an admin, you can always see all member details regardless of their privacy settings.',
                            style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context).withValues(alpha: 0.4),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildItemDivider() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      endIndent: 20,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
    );
  }

  Widget _buildPrivacyToggle(ProfileProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.privacy_tip_rounded,
              size: 20,
              color: AppColors.primary(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detailed Profile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  'Show contributions to others',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          PremiumSwitch(
            value: _showDetailedProfile,
            onChanged: provider.isLoading ? null : (value) => _updatePrivacySetting(value),
            activeColor: AppColors.primary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityItem(IconData icon, String text, bool isVisible) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.textPrimary(context).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isVisible
                  ? AppColors.primary(context)
                  : AppColors.textPrimary(context).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          Icon(
            isVisible ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            color: isVisible ? AppColors.primary(context) : AppColors.textPrimary(context).withValues(alpha: 0.2),
            size: 20,
          ),
        ],
      ),
    );
  }
}





