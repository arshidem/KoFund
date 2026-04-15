// lib/features/profile/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/members/providers/member_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/features/developer/screens/developer_dashboard_screen.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/services/network_service.dart';
import 'package:kofund/core/utils/app_info.dart';
import 'package:kofund/core/widgets/premium_switch.dart';
 
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

    String appVersion = '1.0.0';
  String buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

Future<void> _loadAppInfo() async {
  debugPrint('Loading app info...');
  final version = await AppInfo.appVersion;
  final build = await AppInfo.buildNumber;
  debugPrint('Got version: $version, build: $build');
  
  if (mounted) {
    setState(() {
      appVersion = version;
      buildNumber = build;
    });
    debugPrint('State updated to version: $appVersion');
  }
}

  String? _getUserProvider(User user) {
    if (user.providerData.isEmpty) return null;
    
    final hasGoogleProvider = user.providerData
        .any((userInfo) => userInfo.providerId == 'google.com');
    
    if (hasGoogleProvider) return 'google';
    
    final hasEmailProvider = user.providerData
        .any((userInfo) => userInfo.providerId == 'password');
    
    if (hasEmailProvider) return 'email';
    
    return 'other';
  }
  
  // Removed local _notificationsEnabled state

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AppAuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final profileProvider = context.read<ProfileProvider>();

    return GradientSheetScaffold(
      title: 'Settings',
      body: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
          child: Padding(
            padding: AppStyles.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Settings Section
                _buildSectionHeader('App Preferences'),
                _buildSettingsGroup(
                  children: [
                    _buildSettingsSwitch(
                      context: context,
                      title: 'Push Notifications',
                      subtitle: 'Receive program updates and reminders',
                      value: authProvider.user?.notificationsEnabled ?? true,
                      onChanged: (value) async {
                        final success =
                            await profileProvider.updateNotificationSettings(value);
                        if (success) {
                          await authProvider.refreshUserData();
                          setState(() {});
                        }
                      },
                      icon: Icons.notifications_active_rounded,
                    ),
                    _buildItemDivider(),
                    _buildSettingsSwitch(
                      context: context,
                      title: 'Dark Mode',
                      subtitle: 'Switch to dark theme',
                      value: themeProvider.isDarkMode,
                      onChanged: (value) => themeProvider.toggleTheme(value),
                      icon: Icons.dark_mode_rounded,
                      isCustomSlider: true,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Account Section
                _buildSectionHeader('Account'),
                _buildSettingsGroup(
                  children: [
                    _buildSettingsItem(
                      context: context,
                      title: 'Change Password',
                      icon: Icons.lock_outline_rounded,
                      subtitle: 'Update your security credentials',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.changePassword),
                    ),
                    _buildItemDivider(),
                    _buildSettingsItem(
                      context: context,
                      title: 'Privacy Settings',
                      icon: Icons.privacy_tip_outlined,
                      subtitle: 'Manage your visibility and data',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.privacySettings),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Support Section
                _buildSectionHeader('Support'),
                _buildSettingsGroup(
                  children: [
                    _buildSettingsItem(
                      context: context,
                      title: 'Help & FAQ',
                      icon: Icons.help_outline_rounded,
                      onTap: () => Navigator.pushNamed(context, RouteNames.helpFAQ),
                    ),
                    _buildItemDivider(),
                    _buildSettingsItem(
                      context: context,
                      title: 'Contact Support',
                      icon: Icons.support_agent_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.contactSupport),
                    ),
                    _buildItemDivider(),
                    _buildSettingsItem(
                      context: context,
                      title: 'Report Issue',
                      icon: Icons.bug_report_outlined,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.reportIssue),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Developer Tools Section
                Consumer<AppAuthProvider>(
                  builder: (context, auth, child) {
                    if (auth.isDeveloper) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Developer Tools'),
                          _buildSettingsGroup(
                            children: [
                              _buildSettingsItem(
                                context: context,
                                title: 'Developer Dashboard',
                                icon: Icons.developer_mode_rounded,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DeveloperDashboardScreen(),
                                  ),
                                ),
                                color: Colors.blue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // About Section
                _buildSectionHeader('About'),
                _buildSettingsGroup(
                  children: [
                    _buildSettingsItem(
                      context: context,
                      title: 'Terms of Service',
                      icon: Icons.description_outlined,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.termsOfService),
                    ),
                    _buildItemDivider(),
                    _buildSettingsItem(
                      context: context,
                      title: 'Privacy Policy',
                      icon: Icons.security_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.privacyPolicy),
                    ),
                    _buildItemDivider(),
                    _buildSettingsItem(
                      context: context,
                      title: 'Community Guidelines',
                      icon: Icons.groups_outlined,
                      onTap: () => Navigator.pushNamed(
                          context, RouteNames.communityGuidelines),
                    ),
                    _buildItemDivider(),
                    _buildSettingsItem(
                      context: context,
                      title: 'App Version',
                      icon: Icons.info_outline_rounded,
                      onTap: _showAppInfo,
                      trailing: Text(
                        'v$appVersion',
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Danger Zone
                _buildSectionHeader('Danger Zone', isDangerZone: true),
                _buildSettingsGroup(
                  children: [
                    _buildDangerTile(
                      context: context,
                      icon: Icons.exit_to_app_rounded,
                      title: 'Leave Community',
                      onTap: () => _showLeaveCommunityDialog(
                          context, authProvider, profileProvider),
                    ),
                    _buildItemDivider(),
                    _buildDangerTile(
                      context: context,
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete Account',
                      onTap: () => _showDeleteAccountDialog(authProvider),
                    ),
                    _buildItemDivider(),
                    _buildDangerTile(
                      context: context,
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      onTap: () => _showLogoutDialog(authProvider),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        ],
      ),
    );
}
Widget _buildDangerTile({
  required BuildContext context,
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent, // Important for ripple to show
    child: InkWell(
      onTap: onTap,
      splashColor: AppColors.error(context).withValues(alpha: 0.2), // Custom splash color
      highlightColor: AppColors.error(context).withValues(alpha: 0.1), // Custom highlight color
      borderRadius: BorderRadius.circular(0), // Match card corners
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), // Good height
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.error(context),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.error(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.error(context).withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildSectionHeader(String title, {bool isDangerZone = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isDangerZone 
              ? AppColors.error(context).withValues(alpha: 0.7) 
              : AppColors.textPrimary(context).withValues(alpha: 0.4),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsSwitch({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    bool isCustomSlider = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
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
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
             if (isCustomSlider)
              PremiumSwitch(
                value: value,
                onChanged: onChanged,
                activeIcon: Icons.nightlight_round,
                inactiveIcon: Icons.wb_sunny_rounded,
                activeColor: const Color(0xFF1E1E2C),
                inactiveColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFE0E0E0),
              )
            else
              PremiumSwitch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
    String? subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (color ?? AppColors.primary(context)).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color ?? AppColors.primary(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color ?? AppColors.textPrimary(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.textPrimary(context).withValues(alpha: 0.2),
                  ),
            ],
          ),
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
      indent: 70,
      endIndent: 20,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
    );
  }

  void _showAppInfo() {
    DialogHelper.showConfirmationDialog(
      context,
      title: 'App Information',
      confirmLabel: 'Close',
      cancelLabel: '', // Hide cancel
      icon: Icons.info_outline_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Fund App Community Manager',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Version: $appVersion\nBuild: $buildNumber',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            'A community fund management app for organizing programs and tracking contributions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary(context), height: 1.4),
          ),
        ],
      ),
    );
  }

void _showLeaveCommunityDialog(BuildContext context, AppAuthProvider authProvider, ProfileProvider profileProvider) async {
  final confirm = await DialogHelper.showConfirmationDialog(
    context,
    title: 'Leave Community?',
    message: 'Are you sure you want to leave your current community? You will lose access to all community programs and data.',
    confirmLabel: 'Leave',
    icon: Icons.exit_to_app_rounded,
    isDestructive: true,
  );

  if (confirm == true) {
    // Check internet connection
    final bool isConnected = await NetworkService().isConnected;
    if (!mounted) return;
    
    if (!isConnected) {
      SnackbarHelper.showError(
        context,
        'No internet connection. Please check your network and try again.'
      );
      return;
    }
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Leaving community...'),
        backgroundColor: Colors.orange,
      ),
    );

    final success = await profileProvider.leaveCommunity();
    if (!mounted) return;
    
    if (success) {
      SnackbarHelper.showSuccess(context, 'Successfully left community');
      
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.login,
        (route) => false,
      );
    } else {
      SnackbarHelper.showError(context, 'Failed to leave community: ${profileProvider.error}');
    }
  }
}
void _showDeleteAccountDialog(AppAuthProvider authProvider) async {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    SnackbarHelper.showError(context, 'No user found');
    return;
  }

  final confirm = await DialogHelper.showConfirmationDialog(
    context,
    title: 'Delete Account?',
    confirmLabel: 'Delete Account',
    isDestructive: true,
    icon: Icons.delete_forever_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'This action cannot be undone.\n\nAll your data will be permanently deleted.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        const SizedBox(height: 16),
        
        if (_getUserProvider(user) == 'google') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Google Account User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'You will need to sign in again with Google',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'If deletion fails:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Sign out', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                    Text('2. Sign in again', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                    Text('3. Delete immediately', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  if (confirm == true) {
    // Check internet connection first
    final bool isConnected = await NetworkService().isConnected;
    if (!mounted) return;
    
    if (!isConnected) {
      SnackbarHelper.showError(
        context,
        'No internet connection. Please check your network and try again.'
      );
      return;
    }
    
    final providerType = _getUserProvider(user);
    
    if (providerType == 'google') {
      await _attemptAccountDeletion(profileProvider);
    } else if (providerType == 'email') {
      _showPasswordDialog(profileProvider);
    } else {
      await _attemptAccountDeletion(profileProvider);
    }
  }
}


// New method to show password dialog for email users
void _showPasswordDialog(ProfileProvider profileProvider) {
  TextEditingController passwordController = TextEditingController();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please enter your password to confirm account deletion:'),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              filled: true,
              fillColor: AppColors.surface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
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
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            if (passwordController.text.isNotEmpty) {
              Navigator.pop(context);
              await _attemptAccountDeletion(
                profileProvider,
                password: passwordController.text,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your password')),
              );
            }
          },
          child: const Text('Confirm Delete'),
        ),
      ],
    ),
  );
}

Widget _buildDeletionItem(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.delete_forever, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
}

Future<void> _attemptAccountDeletion(
  ProfileProvider profileProvider, {
  String? password,
}) async {
  try {
    final success = await profileProvider.deleteUserAccount(password: password);
    if (!mounted) return;
    
    if (success) {
      // Account deleted successfully
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate to login screen
      Navigator.pushNamedAndRemoveUntil(
        context, 
        RouteNames.login, // Make sure this is defined in your RouteNames
        (route) => false,
      );
    }
  } on Exception catch (e) {
    if (e.toString().contains('password_required')) {
      // Show password dialog if password is required
      _showPasswordDialog(profileProvider);
    } else if (e.toString().contains('wrong_password')) {
      // Show wrong password snackbar and reopen password dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wrong password. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Reopen password dialog after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showPasswordDialog(profileProvider);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _showReauthenticationRequiredDialog() async {
  final result = await DialogHelper.showConfirmationDialog(
    context,
    title: 'Security Required',
    confirmLabel: 'Sign Out',
    cancelLabel: 'Cancel',
    icon: Icons.security_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Recent Sign-in Needed',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary(context)),
        ),
        const SizedBox(height: 12),
        Text(
          'Google requires recent authentication to delete your account. Please sign out and sign in again to proceed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context), height: 1.4),
        ),
      ],
    ),
  );

  if (result == true) {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.login,
      (route) => false,
    );
  }
}

  void _showLogoutDialog(AppAuthProvider authProvider) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final memberProvider = Provider.of<MemberProvider>(context, listen: false);
    
    final confirm = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Logout?',
      message: 'Are you sure you want to logout? You will need to sign in again to access your account.',
      confirmLabel: 'Logout',
      icon: Icons.logout_rounded,
      isDestructive: true,
    );

    if (confirm == true) {
      // Check internet connection first
      final bool isConnected = await NetworkService().isConnected;
      if (!mounted) return;
      
      if (!isConnected) {
        SnackbarHelper.showError(
          context, 
          'No internet connection. Please check your network and try again.'
        );
        return;
      }
      
      // 1. Clear ALL provider data first
      profileProvider.clearAllData();
      memberProvider.clearDataForUserChange();
      
      // 2. Sign out from auth
      await authProvider.signOut(context);
      if (!mounted) return;
      
      // 3. Show success message
      SnackbarHelper.showSuccess(context, 'Logged out successfully!');

      // 4. Navigate to login
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.login,
        (route) => false,
      );
    }
  }
}


