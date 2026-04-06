import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_sheet_scaffold.dart';
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/community_provider.dart';
import '../../../core/constants/app_dimensions.dart';
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
        title: Row(
          children: [
            Icon(Icons.link, color: AppColors.primary(context)),
            const SizedBox(width: 10),
            Text('Join Invitation'),
            
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve received an invitation to join a community.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 10),
          Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),

    // ✅ SAME gradient system used app-wide
    gradient: LinearGradient(
      colors: [
        Colors.blue.withValues(alpha: 0.15),
        Colors.blue.withValues(alpha: 0.05),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),

    // ✅ SAME border style
    border: Border.all(
      color: Colors.blue.withValues(alpha: 0.25),
    ),

    // ✅ SAME soft shadow
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Row(
    children: [
      Icon(
        Icons.code,
        color: Colors.blue.shade700,
        size: 20,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite Code',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _codeController.text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
                letterSpacing: 1,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
            ),
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
      user.email.split('@').first ??
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
    // ✅ Navigate ALL users to pending approval
    Navigator.pushReplacementNamed(context, RouteNames.pendingApproval);
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 100,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength),
      ],
      validator: validator,
      textCapitalization: TextCapitalization.characters,
      style: TextStyle(
        color: AppColors.textPrimary(context),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColors.primary(context),
          fontWeight: FontWeight.w600,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary(context).withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.primary(context),
          size: 20,
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        counterText: '',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

@override
Widget build(BuildContext context) {
  return GradientSheetScaffold(
    title: 'Join Community',
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        Navigator.pushReplacementNamed(context, RouteNames.login);
      },
    ),
    body: SafeArea(
      // ... rest of the body code remains the same
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ✅ Logo Header (consistent with CreateCommunityScreen)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                child: Column(
                  children: [
                    // Logo with rounded background
                    Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary(context),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(context).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logos/KoFund.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Join Community',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Deep link indicator
              if (widget.inviteCode != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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

              const SizedBox(height: 8),
              Text(
                'Enter the community code to send a join request',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Rest of your form...
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Community Code Input
                      _buildInputField(
                        controller: _codeController,
                        label: 'Community Code',
                        hint: 'Enter 8-digit code (e.g., ABC12345)',
                        icon: Icons.code,
                        maxLength: 8,
                        isRequired: true,
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

                      // Info Card - Matching CreateCommunityScreen style
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withValues(alpha: 0.15),
                              Colors.blue.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.25),
                          ),
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
                                      'How to Join',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '• Ask the community admin for the 8-digit code\n'
                                      '• Public communities will add you immediately\n'
                                      '• Private communities require admin approval\n'
                                      '• Codes contain only uppercase letters & numbers',
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

                      // Join Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _autoJoining ? null : _joinCommunity,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.primary(context).withValues(alpha: 0.4),
                          ),
                          child: _autoJoining
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.group_add_rounded, size: 20),
                                    SizedBox(width: 12),
                                    Text(
                                      'Join Community',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),


                      const SizedBox(height: 20),

                      // OR Divider
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

                      // Create Community Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateCommunityScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primary(context),
                          ),
                          label: Text(
                            'Create New Community',
                            style: TextStyle(
                              color: AppColors.primary(context),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.primary(context),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Help Section
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            Text(
                              'Having trouble?',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                          '4. Click "Join Community" to send request after fiil the code',
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
                                  icon: Icon(Icons.help_outline, 
                                      color: AppColors.primary(context), size: 20),
                                  tooltip: 'Help',
                                )
                               
                              ],
                            ),
                          ],
                        ),
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
