import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart'; // ADD THIS IMPORT
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/models/user_model.dart';

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
    final authProvider = context.read<AppAuthProvider>(); // Use AppAuthProvider
    final user = authProvider.user; // This is UserModel
    
    if (user != null) {
      setState(() {
        _showDetailedProfile = user.showDetailedProfile ?? false; // Add null check
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
        // Revert UI on error
        setState(() => _showDetailedProfile = !newValue);
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to update privacy settings: $e');
      setState(() => _showDetailedProfile = !newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>(); // Watch AppAuthProvider
    final profileProvider = context.watch<ProfileProvider>();
    final user = authProvider.user; // Get UserModel from AppAuthProvider

    if (user == null || !_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Privacy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: profileProvider.isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Privacy Toggle Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Show Detailed Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Allow others to see your contributions and program details'),
                      value: _showDetailedProfile,
                      onChanged: profileProvider.isLoading ? null : (value) {
                        _updatePrivacySetting(value);
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Visual Indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _showDetailedProfile ? Colors.green[50] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _showDetailedProfile ? Colors.green : Colors.blue,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showDetailedProfile ? Icons.visibility : Icons.visibility_off,
                            color: _showDetailedProfile ? Colors.green : Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _showDetailedProfile 
                                ? 'Others can see your contributions and program details'
                                : 'Others can only see your basic profile information',
                              style: TextStyle(
                                color: _showDetailedProfile ? Colors.green[700] : Colors.blue[700],
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
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What others can see:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    
                    // Always visible items
                    _buildVisibilityItem('👤', 'Your name', true),
                    _buildVisibilityItem('📧', 'Your email', true),
                    _buildVisibilityItem('📱', 'Your phone number', true),
                    _buildVisibilityItem('🎯', 'Program participation count', true),
                    _buildVisibilityItem('👥', 'Your role in community', true),
                    _buildVisibilityItem('📅', 'Join date', true),
                    
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Only visible when toggle is ON
                    _buildVisibilityItem('💰', 'Contribution amounts', _showDetailedProfile),
                    _buildVisibilityItem('📝', 'Which specific programs you joined', _showDetailedProfile),
                    _buildVisibilityItem('📊', 'Your contribution history', _showDetailedProfile),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Admin Note
            if (user.role == 'admin') ...[ // Use user.role instead of user.isAdmin
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'As an admin, you can always see all member details regardless of their privacy settings.',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            if (profileProvider.isLoading) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text('Updating privacy settings...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityItem(String emoji, String text, bool isVisible) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          Icon(
            isVisible ? Icons.check_circle : Icons.remove_circle,
            color: isVisible ? Colors.green : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }
}