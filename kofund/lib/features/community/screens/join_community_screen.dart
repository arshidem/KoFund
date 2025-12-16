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
  final String? inviteCode;
  
  const JoinCommunityScreen({
    super.key,
    this.inviteCode,
  });

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _autoJoining = false;
  bool _showAutoJoinPrompt = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty) {
      _codeController.text = widget.inviteCode!.toUpperCase().trim();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isValidInviteCode(_codeController.text)) {
          _showAutoJoinDialog();
        }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _isValidInviteCode(String code) {
    final trimmedCode = code.trim();
    return trimmedCode.length == 8 && 
           RegExp(r'^[A-Z0-9]{8}$').hasMatch(trimmedCode);
  }

  void _showAutoJoinDialog() {
    if (!mounted || _showAutoJoinPrompt) return;
    
    _showAutoJoinPrompt = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.blue),
            SizedBox(width: 10),
            Text('Join Invitation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You\'ve received an invitation to join a community.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.code, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Code:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          _codeController.text,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Would you like to join this community?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _showAutoJoinPrompt = false;
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _showAutoJoinPrompt = false;
              Navigator.pop(context);
              _joinCommunity();
            },
            child: const Text('Join Now'),
          ),
        ],
      ),
    ).then((_) {
      _showAutoJoinPrompt = false;
    });
  }

  Future<void> _joinCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _autoJoining = true;
    });

    final authProvider = context.read<AppAuthProvider>();
    final communityProvider = context.read<CommunityProvider>();

    final user = authProvider.user;
    if (user == null) {
      SnackbarHelper.showError(context, 'User not authenticated');
      setState(() {
        _autoJoining = false;
      });
      return;
    }

    final String userName = user.displayName ??
        user.email?.split('@').first ??
        'User';

    final success = await communityProvider.joinCommunityByCode(
      code: _codeController.text.trim().toUpperCase(),
      userId: user.uid,
      userEmail: user.email ?? '',
      userName: userName,
    );

    if (!mounted) {
      setState(() {
        _autoJoining = false;
      });
      return;
    }

    if (success) {
      final community = communityProvider.currentCommunity;

      if (community?.type == 'Private') {
        Navigator.pushReplacementNamed(context, RouteNames.pendingApproval);
      } else {
        await authProvider.refreshUserData();
        Navigator.pushReplacementNamed(context, RouteNames.communityDashboard);
      }
    } else {
      SnackbarHelper.showError(
        context,
        communityProvider.error ?? 'Failed to join community',
      );
    }

    setState(() {
      _autoJoining = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Community'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
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
                // Deep link indicator
                if (widget.inviteCode != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invitation Received',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Code pre-filled from invitation link',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

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
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ask the community admin for the 8-digit join code. '
                            'Public communities will add you immediately, while '
                            'private communities require admin approval.',
                            style: TextStyle(
                              color: Colors.blue.shade800,
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
                    final isLoading = provider.isLoading || _autoJoining;
                    
                    return CustomButton(
                      onPressed: isLoading ? null : _joinCommunity,
                      text: isLoading
                          ? 'Joining...'
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
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
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

                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      Text(
                        'Having trouble?',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              SnackbarHelper.showInfo(
                                context,
                                'Make sure the code is exactly 8 characters long',
                              );
                            },
                            icon: Icon(Icons.help_outline, 
                                color: Colors.blue.shade600, size: 20),
                            tooltip: 'Help',
                          ),
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('How to Get a Code'),
                                  content: const Text(
                                    '1. Ask a community admin for the 8-digit code\n'
                                    '2. Make sure the code is in uppercase\n'
                                    '3. Codes contain only letters (A-Z) and numbers (0-9)\n'
                                    '4. Click "Join Community" to send request',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: Icon(Icons.question_mark, 
                                color: Colors.blue.shade600, size: 20),
                            tooltip: 'Instructions',
                          ),
                        ],
                      ),
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