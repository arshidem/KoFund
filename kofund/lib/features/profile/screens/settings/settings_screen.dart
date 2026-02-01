// lib/features/profile/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/members/providers/member_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/features/developer/screens/developer_dashboard_screen.dart';
import 'package:kofund/features/developer/screens/add_developer_screen.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/services/network_service.dart';
import 'dart:ui';
import 'package:kofund/core/utils/app_info.dart';
import 'package:flutter/foundation.dart' show debugPrint;
 
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
  
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AppAuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final profileProvider = context.read<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.background(context),
appBar: AppBar(
  toolbarHeight: 80, // Set your desired height here (default is 56)
  title: const Text(
    'Settings',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
 

            // App Settings Section
            _buildSectionHeader('App Preferences'),
            Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingsSwitch(
                    context: context,
                    title: 'Push Notifications',
                    subtitle: 'Receive program updates and reminders',
                    value: _notificationsEnabled,
                    onChanged: (value) => setState(() => _notificationsEnabled = value),
                    icon: Icons.notifications_active,
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  _buildSettingsSwitch(
                    context: context,
                    title: 'Dark Mode',
                    subtitle: 'Switch to dark theme',
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => themeProvider.toggleTheme(value),
                    icon: Icons.dark_mode,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account Section
            _buildSectionHeader('Account'),
            Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    context: context,
                    title: 'Change Password',
                    icon: Icons.lock,
                    onTap: () => Navigator.pushNamed(context, RouteNames.changePassword),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  _buildSettingsItem(
                    context: context,
                    title: 'Privacy Settings',
                    icon: Icons.privacy_tip,
                    onTap: () => Navigator.pushNamed(context, RouteNames.privacySettings),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support Section
            _buildSectionHeader('Support'),
            Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    context: context,
                    title: 'Help & FAQ',
                    icon: Icons.help,
                    onTap: () => Navigator.pushNamed(context, RouteNames.helpFAQ),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  _buildSettingsItem(
                    context: context,
                    title: 'Contact Support',
                    icon: Icons.support_agent,
                    onTap: () => Navigator.pushNamed(context, RouteNames.contactSupport),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  _buildSettingsItem(
                    context: context,
                    title: 'Report Issue',
                    icon: Icons.bug_report,
                    onTap: () => Navigator.pushNamed(context, RouteNames.reportIssue),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Developer Tools Section
            Consumer<AppAuthProvider>(
              builder: (context, auth, child) {
                if (auth.isDeveloper) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Developer Tools'),
                      Card(
                        color: AppColors.card(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildSettingsItem(
                          context: context,
                          title: 'Developer Dashboard',
                          icon: Icons.developer_mode,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeveloperDashboardScreen(),
                            ),
                          ),
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // About Section
            _buildSectionHeader('About'),
            Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    context: context,
                    title: 'Terms of Service',
                    icon: Icons.description,
                    onTap: () => Navigator.pushNamed(context, RouteNames.termsOfService),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  _buildSettingsItem(
                    context: context,
                    title: 'Privacy Policy',
                    icon: Icons.security,
                    onTap: () => Navigator.pushNamed(context, RouteNames.privacyPolicy),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  _buildSettingsItem(
                    context: context,
                    title: 'Community Guidelines',
                    icon: Icons.groups,
                    onTap: () => Navigator.pushNamed(context, RouteNames.communityGuidelines),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  _buildSettingsItem(
                    context: context,
                    title: 'App Version',
                    icon: Icons.info,
                    onTap: _showAppInfo,
                    trailing: Text(
                      'v$appVersion',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Danger Zone
_buildSectionHeader('Danger Zone', isDangerZone: true), // Add isDangerZone parameter
Card(
  color: Colors.transparent,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    children: [
      // Removed the warning banner container
      
      // Actions only
      Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12), // Changed to all corners
        ),
        child: Column(
          children: [
            _buildDangerTile(
              context: context,
              icon: Icons.exit_to_app,
              title: 'Leave Community',
              onTap: () => _showLeaveCommunityDialog(context, authProvider, profileProvider),
            ),
            Divider(height: 1, color: AppColors.border(context)),
            _buildDangerTile(
              context: context,
              icon: Icons.delete_forever,
              title: 'Delete Account',
              onTap: () => _showDeleteAccountDialog(authProvider),
            ),
            Divider(height: 1, color: AppColors.border(context)),
            _buildDangerTile(
              context: context,
              icon: Icons.logout,
              title: 'Logout',
              onTap: () => _showLogoutDialog(authProvider),
            ),
          ],
        ),
      ),
    ],
  ),
),

const SizedBox(height: 32),
],
),
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
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDangerZone ? AppColors.error(context) : AppColors.textPrimary(context), // Red for danger zone
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
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.textSecondary(context),
        ),
      ),
      value: value,
      onChanged: onChanged,
      secondary: Icon(
        icon,
        color: AppColors.primary(context),
      ),
      activeColor: AppColors.primary(context),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? AppColors.primary(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppColors.textPrimary(context),
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: color ?? AppColors.textSecondary(context),
        size: 18,
      ),
      onTap: onTap,
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'App Information',
          style: TextStyle(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.card(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fund App Community Manager',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version: $appVersion',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            Text(
              'Build: $buildNumber',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'A community fund management app for organizing programs and tracking contributions.',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.primary(context)),
            ),
          ),
        ],
      ),
    );
  }

void _showLeaveCommunityDialog(BuildContext context, AppAuthProvider authProvider, ProfileProvider profileProvider) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Leave Community?',
        style: TextStyle(color: AppColors.textPrimary(context)),
      ),
      backgroundColor: AppColors.card(context),
      content: Text(
        'Are you sure you want to leave your current community? You will lose access to all community programs and data.',
        style: TextStyle(color: AppColors.textSecondary(context)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
        TextButton(
          onPressed: () async {
            // Check internet connection first
            final bool isConnected = await NetworkService().isConnected;
            if (!mounted) return;
            
            if (!isConnected) {
              // Show snackbar and keep dialog open
              SnackbarHelper.showError(
                context,
                'No internet connection. Please check your network and try again.'
              );
              return; // Don't close dialog or proceed
            }
            
            // If connected, proceed with leaving
            Navigator.pop(context);
            
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
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Successfully left community'),
                  backgroundColor: Colors.green,
                ),
              );
              
              Navigator.pushNamedAndRemoveUntil(
                context,
                RouteNames.login,
                (route) => false,
              );
            } else {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Failed to leave community: ${profileProvider.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error(context),
          ),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
}
void _showDeleteAccountDialog(AppAuthProvider authProvider) {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    SnackbarHelper.showError(context, 'No user found');
    return;
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Delete Account?',
        style: TextStyle(color: AppColors.textPrimary(context)),
      ),
      backgroundColor: AppColors.card(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This action cannot be undone.\n\n'
            'All your data will be permanently deleted.',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 10),
          
          if (_getUserProvider(user) == 'google') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_circle, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
            const SizedBox(height: 10),
          ],
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
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
                      Text(
                        '1. Sign out',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      Text(
                        '2. Sign in again',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      Text(
                        '3. Delete immediately',
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error(context),
          ),
          onPressed: () async {
            // Check internet connection first
            final bool isConnected = await NetworkService().isConnected;
            if (!mounted) return;
            
            if (!isConnected) {
              // Show snackbar and keep dialog open
              SnackbarHelper.showError(
                context,
                'No internet connection. Please check your network and try again.'
              );
              return; // Don't close dialog or proceed
            }
            
            // If connected, proceed with deletion
            Navigator.pop(context);
            final providerType = _getUserProvider(user);
            
            if (providerType == 'google') {
              await _attemptAccountDeletion(profileProvider);
            } else if (providerType == 'email') {
              _showPasswordDialog(profileProvider);
            } else {
              await _attemptAccountDeletion(profileProvider);
            }
          },
          child: const Text('Delete Account'),
        ),
      ],
    ),
  );
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
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
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

void _showReauthenticationRequiredDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Security Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.orange[700], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Recent Sign-in Needed',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Google requires recent authentication to delete your account.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text('Please:'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Sign out', style: const TextStyle(fontSize: 14)),
                Text('2. Sign in again', style: const TextStyle(fontSize: 14)),
                Text('3. Delete immediately', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.login,
              (route) => false,
            );
          },
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
}

void _showLogoutDialog(AppAuthProvider authProvider) {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final memberProvider = Provider.of<MemberProvider>(context, listen: false);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout?'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            // Check internet connection first
            final bool isConnected = await NetworkService().isConnected;
            if (!mounted) return;
            
            if (!isConnected) {
              // Show snackbar and close dialog
              Navigator.pop(context);
              SnackbarHelper.showError(
                context, 
                'No internet connection. Please check your network and try again.'
              );
              return;
            }
            
            Navigator.pop(context); // close the dialog
            
            // 1. Clear ALL provider data first
            profileProvider.clearAllData();
            memberProvider.clearDataForUserChange();
            // Add other providers as needed
            
            // 2. Sign out from auth
            await authProvider.signOut(context);
            if (!mounted) return;
            
            // 3. Show success message
            SnackbarHelper.showSuccess(context, 'Logged out successfully!');

            // 4. Navigate to login screen & clear navigation history
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                RouteNames.login,
                (route) => false,
              );
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}
}


