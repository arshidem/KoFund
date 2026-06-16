import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/community_provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
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

  void _showAutoJoinDialog() async {
    if (!mounted || _showAutoJoinPrompt) return;
    
    setState(() {
      _showAutoJoinPrompt = true;
    });
    
    final shouldJoin = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Join Invitation',
      icon: Icons.link_rounded,
      confirmLabel: 'Join Now',
      cancelLabel: 'Cancel',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You\'ve received an invitation to join a community.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary(context).withOpacity(0.15),
                  AppColors.primary(context).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.primary(context).withOpacity(0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code_rounded,
                  color: AppColors.primary(context),
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
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _codeController.text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Would you like to join this community?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() {
        _showAutoJoinPrompt = false;
      });
      if (shouldJoin == true) {
        _joinCommunity();
      }
    }
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
      userEmail: user.email,
      userName: userName,
    );

    if (success) {
      await authProvider.refreshUserData();
    }

    if (!mounted) {
      setState(() {
        _autoJoining = false;
      });
      return;
    }

    if (success) {
      // ✅ Navigate ALL users to pending approval
      context.go(RouteNames.pendingApproval);
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
  final List<TextInputFormatter> formatters = [
    LengthLimitingTextInputFormatter(maxLength),
  ];

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primary = AppColors.primary(context);
  final errorColor = Theme.of(context).colorScheme.error;

  String? _currentError;

  return StatefulBuilder(
    builder: (context, setFieldState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface(context) : Colors.white,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: formatters,
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                final error = validator?.call(value);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setFieldState(() => _currentError = error);
                });
                return error;
              },
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 15,
              ),
            decoration: InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(
    color: AppColors.textTertiary(context),
    fontSize: 15,
  ),
  // Suppress Flutter's native error text and space
  errorStyle: const TextStyle(
    fontSize: 0,
    height: 0.001,
    color: Colors.transparent,
  ),
  prefixIcon: Padding(
    padding: const EdgeInsets.only(left: 20, right: 12),
    child: Icon(
      icon,
      color: primary,
      size: 22,
    ),
  ),
  prefixIconConstraints: const BoxConstraints(
    minWidth: 54,
    minHeight: 40,
  ),
  contentPadding: const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 18,
  ),
  // Set ALL border states to the same style (no red border)
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(100),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(100),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(100),
    borderSide: BorderSide(
      color: primary.withValues(alpha: 0.5),
      width: 1.5,
    ),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(100),
    borderSide: BorderSide.none, // No red border on error
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(100),
    borderSide: BorderSide.none, // No red border on focused error
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(100),
    borderSide: BorderSide.none,
  ),
  counterText: '',
),
              onChanged: (value) {
                setFieldState(() {
                  _currentError = validator?.call(value);
                });
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _currentError != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 20, top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: errorColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _currentError!,
                            style: TextStyle(
                              color: errorColor,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.read<AppAuthProvider>().signOut(context);
        context.go(RouteNames.login);
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary(context)),
            onPressed: () {
              context.read<AppAuthProvider>().signOut(context);
              context.go(RouteNames.login);
            },
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Curved Decorative Background Shapes (Teal/Mint overlays)
            Positioned(
              top: -180,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: -120,
              left: -120,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: -60,
              left: -140,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10),
                            // Brand Logo & Text
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary(context),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary(context).withOpacity(0.25),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/logos/KoFund.svg',
                                        height: 44,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.8,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Ko',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'Fund',
                                          style: TextStyle(
                                            color: AppColors.primary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Header Typography
                            Center(
                              child: Text(
                                'Join Community',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Enter the community code to send a join request',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Deep link indicator
                            if (widget.inviteCode != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.green.withOpacity(0.2)),
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
                              const SizedBox(height: 16),
                            ],

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

                                  // Info Card
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withOpacity(0.12),
                                          Colors.blue.withOpacity(0.04),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.2),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
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
                                                    fontWeight: FontWeight.bold,
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

                                  const SizedBox(height: 24),

                                  // Join Button
                                  Container(
                                    height: 56,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: [
                                        if (!_autoJoining)
                                          BoxShadow(
                                            color: AppColors.primary(context).withOpacity(0.25),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _autoJoining ? null : _joinCommunity,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary(context),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                      child: _autoJoining
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
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

                                  const SizedBox(height: 18),

                                  // OR Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: AppColors.border(context),
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            color: AppColors.textTertiary(context),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: AppColors.border(context),
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 18),

                                  // Create Community Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const CreateCommunityScreen(),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: AppColors.primary(context),
                                          width: 1.5,
                                        ),
                                        backgroundColor: isDark ? AppColors.surface(context) : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: AppColors.primary(context),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Create New Community',
                                            style: TextStyle(
                                              color: AppColors.primary(context),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Help Section
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          'Having trouble?',
                                          style: TextStyle(
                                            color: AppColors.textSecondary(context),
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
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
                                                  '4. Click "Join Community" to send request after filling the code',
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
                                          icon: Icon(
                                            Icons.help_outline_rounded,
                                            color: AppColors.primary(context),
                                            size: 22,
                                          ),
                                          tooltip: 'Help',
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
