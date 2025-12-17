// lib/features/profile/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/features/members/providers/member_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AppAuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
  final profileProvider = context.read<ProfileProvider>(); // ✅ ADD THIS

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Settings Section
          _buildSectionHeader('App Settings'),
          _buildSettingsCard([
            _buildSettingsSwitch(
              'Push Notifications',
              'Receive program updates and reminders',
              _notificationsEnabled,
              (value) => setState(() => _notificationsEnabled = value),
              icon: Icons.notifications_active,
            ),
            _buildSettingsSwitch(
              'Dark Mode',
              'Switch to dark theme',
              themeProvider.isDarkMode,
              (value) => themeProvider.toggleTheme(value),
              icon: Icons.dark_mode,
            ),
          ]),

          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsCard([
            _buildSettingsItem(
              'Change Password',
              Icons.lock,
              () => Navigator.pushNamed(context, RouteNames.changePassword),
            ),
            _buildSettingsItem(
              'Privacy Settings',
              Icons.privacy_tip,
              () => Navigator.pushNamed(context, RouteNames.privacySettings),
            ),
          ]),

          // Support Section
          _buildSectionHeader('Support'),
          _buildSettingsCard([
            _buildSettingsItem(
              'Help & FAQ',
              Icons.help,
              () => Navigator.pushNamed(context, RouteNames.helpFAQ),
            ),
            _buildSettingsItem(
              'Contact Support',
              Icons.support_agent,
              () => Navigator.pushNamed(context, RouteNames.contactSupport),
            ),
            _buildSettingsItem(
              'Report Issue',
              Icons.bug_report,
              () => Navigator.pushNamed(context, RouteNames.reportIssue),
            ),
          ]),

          // About Section
          _buildSectionHeader('About'),
          _buildSettingsCard([
            _buildSettingsItem(
              'Terms of Service',
              Icons.description,
              () => Navigator.pushNamed(context, RouteNames.termsOfService),
            ),
            _buildSettingsItem(
              'Privacy Policy',
              Icons.security,
              () => Navigator.pushNamed(context, RouteNames.privacyPolicy),
            ),
                          _buildSettingsItem(
                'Community Guidelines',
                Icons.groups,
                () => Navigator.pushNamed(context, RouteNames.communityGuidelines),
              ),
            _buildSettingsItem(
              'App Version',
              Icons.info,
              () => _showAppInfo(),
              trailing: Text(
                'v1.0.0',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ]),

          // Danger Zone
          _buildSectionHeader('Danger Zone'),
          Card(
            color: Colors.red[50],
            child: Column(
              children: [
              _buildSettingsItem(
  'Leave Community',
  Icons.exit_to_app,
  () => _showLeaveCommunityDialog(context, authProvider, profileProvider), // ✅ Use profileProvider variable
  color: Colors.red,
),
                _buildSettingsItem(
                  'Delete Account',
                  Icons.delete_forever,
                  () => _showDeleteAccountDialog(authProvider),
                  color: Colors.red,
                ),
                _buildSettingsItem(
                  'Logout',
                  Icons.logout,
                  () => _showLogoutDialog(authProvider),
                  color: Colors.red,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 1,
      child: Column(children: children),
    );
  }

  Widget _buildSettingsSwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    IconData icon = Icons.settings,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: Colors.blue[600]),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, VoidCallback onTap,
      {Color? color, Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blue[600]),
      title: Text(title, style: TextStyle(color: color)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: color ?? Colors.grey),
      onTap: onTap,
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fund App Community Manager'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            Text('Build: 2024.01.01'),
            SizedBox(height: 8),
            Text('A community fund management app for organizing programs and tracking contributions.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

void _showLeaveCommunityDialog(BuildContext context, AppAuthProvider authProvider, ProfileProvider profileProvider) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Leave Community?'),
      content: const Text(
        'Are you sure you want to leave your current community? You will lose access to all community programs and data.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog first
            
            // Show loading
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Leaving community...')),
            );

            // ✅ ACTUALLY LEAVE THE COMMUNITY
            final success = await profileProvider.leaveCommunity();
            
            if (success) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Successfully left community')),
              );
              
              // Navigate to login and clear all previous routes
              Navigator.pushNamedAndRemoveUntil(
                context,
                RouteNames.login,
                (route) => false,
              );
            } else {
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('Failed to leave community: ${profileProvider.error}')),
              );
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
}

void _showDeleteAccountDialog(AppAuthProvider authProvider) {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This action cannot be undone.\n\n'
            'All your data will be permanently deleted from:',
          ),
          const SizedBox(height: 10),
  
      Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.orange[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.orange),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Icon and heading in same row
      Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Text(
            'If deletion fails:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      // Left-aligned numbered list
      Padding(
        padding: const EdgeInsets.only(left: 26), // Align with text
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Sign out',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '2. Sign in again',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '3. Delete immediately',
              style: const TextStyle(fontSize: 12),
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(context);
            await _attemptAccountDeletion(profileProvider);
          },
          child: const Text('Delete Account'),
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

Future<void> _attemptAccountDeletion(ProfileProvider profileProvider) async {
  // Show loading
  SnackbarHelper.showInfo(context, 'Deleting your account...');
  
  final success = await profileProvider.deleteUserAccount();
  
  if (!context.mounted) return;
  
  if (success) {
    SnackbarHelper.showSuccess(
      context, 
      'Account deleted successfully!'
    );
    
    // Navigate to login
    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.login,
      (route) => false,
    );
  } else {
    // Check if it's the requires-recent-login error
    final error = profileProvider.error ?? '';
    if (error.contains('requires-recent-login') || 
        error.contains('sign out and sign in again')) {
      // Show special dialog for this case
      _showReauthenticationRequiredDialog();
    } else {
      SnackbarHelper.showError(context, error);
    }
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
            Navigator.pop(context); // close the dialog
            
            // 1. Clear ALL provider data first
            profileProvider.clearAllData();
            memberProvider.clearAllData();
            // Add other providers as needed
            
            // 2. Sign out from auth
            await authProvider.signOut(context);
            
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