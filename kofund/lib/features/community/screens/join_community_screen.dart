import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/community_provider.dart';
import 'create_community_screen.dart';

class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AppAuthProvider>();
    final communityProvider = context.read<CommunityProvider>();

    final user = authProvider.user;
    if (user == null) {
      SnackbarHelper.showError(context, 'User not authenticated');
      return;
    }

    final String userName = user.displayName ??
        user.email?.split('@').first ??
        'User';

    // Attempt to join community
    final success = await communityProvider.joinCommunityByCode(
      code: _codeController.text.trim().toUpperCase(),
      userId: user.uid,
      userEmail: user.email ?? '',
      userName: userName,
    );

    if (!mounted) return;

    if (success) {
      final community = communityProvider.currentCommunity;

      if (community?.type == 'Private') {
        // Private: Wait for admin approval
        Navigator.pushReplacementNamed(context, RouteNames.pendingApproval);
      } else {
        // Public: Direct access - refresh user data
        await authProvider.refreshUserData();
        Navigator.pushReplacementNamed(context, RouteNames.communityDashboard);
      }
    } else {
      SnackbarHelper.showError(
        context,
        communityProvider.error ?? 'Failed to join community',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   appBar: AppBar(
  title: const Text('Join Community'),
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      // Navigate to /login and clear any previous routes
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.login,
        (route) => false,
      );
    },
  ),
),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.group_add, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'Join Existing Community',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the community code to send a join request',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                CustomTextField(
                  controller: _codeController,
                  label: 'Community Code',
                  hintText: 'Enter 8-digit code (e.g., ABC12345)',
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter community code';
                    }
                    final trimmedValue = value.trim();
                    if (trimmedValue.length != 8) {
                      return 'Code must be 8 characters';
                    }
                    if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(trimmedValue)) {
                      return 'Code must contain only letters and numbers';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ask the community admin for the 8-digit join code. '
                            'Public communities will add you immediately, while '
                            'private communities require admin approval.',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Consumer<CommunityProvider>(
                  builder: (context, provider, _) {
                    return CustomButton(
                      onPressed: provider.isLoading ? null : _joinCommunity,
                      text: provider.isLoading
                          ? 'Processing...'
                          : 'Join Community',
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

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateCommunityScreen(),
                      ),
                    );
                  },
                  icon:
                      const Icon(Icons.add_circle_outline, color: Colors.blue),
                  label: const Text(
                    'Create New Community',
                    style: TextStyle(color: Colors.blue),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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