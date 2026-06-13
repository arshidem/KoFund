import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kofund/core/constants/app_colors.dart';
import '../providers/app_auth_provider.dart';
import 'register_screen.dart';
import 'splash_screen.dart';
import 'verification_pending_screen.dart';
import 'forgot_password_screen.dart';
import 'set_phone_screen.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/community/screens/join_community_screen.dart';
import 'package:kofund/core/services/network_service.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kofund/features/profile/screens/settings/terms_of_service_screen.dart';
import 'package:kofund/features/profile/screens/settings/privacy_policy_screen.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  final String? pendingInviteCode;
  const LoginScreen({super.key, this.pendingInviteCode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _externalWebsiteUrl = 'https://kofund.app';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showInviteNotification = false;
  bool _termsAccepted = false;

  String? _cachedInviteCode;
  String? _emailError;
  String? _passwordError;
  String? _termsError;
  String? _formError; // network / auth
  String? _errorMessage; // For general auth errors

  @override
  void initState() {
    super.initState();
    _checkForPendingInvite();
  }

  /// ⭐ NEW: Check for pending invite code
  Future<void> _checkForPendingInvite() async {
    // First check if invite code was passed directly
    if (widget.pendingInviteCode != null) {
      _cachedInviteCode = widget.pendingInviteCode;
      _showInviteNotification = true;
      debugPrint('🎯 LoginScreen received invite code: $_cachedInviteCode');
      return;
    }

    // Then check storage for any pending invites
    final prefs = await SharedPreferences.getInstance();
    final storedInviteCode = prefs.getString('pending_invite_code');

    if (storedInviteCode != null && storedInviteCode.isNotEmpty) {
      _cachedInviteCode = storedInviteCode;
      _showInviteNotification = true;
      debugPrint('📋 LoginScreen found stored invite code: $_cachedInviteCode');
    }
  }

  /// ⭐ NEW: Clear pending invite code
  Future<void> _clearPendingInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_invite_code');
    _cachedInviteCode = null;
    _showInviteNotification = false;
    debugPrint('🗑️ LoginScreen cleared pending invite code');
  }

  /// ⭐ NEW: Navigate to join community with invite
  void _navigateToJoinCommunityWithInvite() {
    if (_cachedInviteCode == null) {
      debugPrint('❌ No invite code to navigate with');
      return;
    }

    debugPrint(
      '🚀 Navigating to join community with invite: $_cachedInviteCode',
    );

    // Clear the invite from storage
    unawaited(_clearPendingInviteCode());

    context.go('${RouteNames.joinCommunity}?code=$_cachedInviteCode');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Clear previous errors
    setState(() {
      _emailError = null;
      _passwordError = null;
      _formError = null;
      _errorMessage = null;
      _termsError = null;
    });
    if (!_termsAccepted) {
      setState(() {
        _termsError = 'Please accept Terms of Service and Privacy Policy';
      });
      return;
    }

    // Network check first
    try {
      final hasNetwork = await NetworkService().isConnected;
      if (!hasNetwork) {
        setState(() {
          _formError = 'Connect to internet to login';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _formError = 'Unable to check network connection';
      });
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    bool hasError = false;

    // Email validation
    if (email.isEmpty) {
      _emailError = 'Email is required';
      hasError = true;
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _emailError = 'Enter a valid email';
      hasError = true;
    }

    // Password validation
    if (password.isEmpty) {
      _passwordError = 'Password is required';
      hasError = true;
    } else if (password.length < 6) {
      _passwordError = 'Minimum 6 characters';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      // Clear previous provider errors
      authProvider.clearError();
      
      final success = await authProvider.signIn(
        email: email,
        password: password,
      );

      if (success && mounted) {
        _showSuccess('Login successful!');

        // Check if we have pending invite
        if (_cachedInviteCode != null) {
          debugPrint(
            '✅ Login successful, navigating to join community with invite',
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          _navigateToJoinCommunityWithInvite();
        } else {
          // Normal flow - go to splash screen
          debugPrint('✅ Login successful, normal flow to splash');
          context.go(RouteNames.splash);
        }
      } else if (mounted) {
        if (authProvider.shouldNavigateToVerification) {
          _showError('Please verify your email to continue.');
          final userEmail = authProvider.currentUserEmail ?? email;
          context.go('${RouteNames.verificationPending}?email=$userEmail');
        } else {
          _showError(authProvider.error ?? 'Login failed. Please try again.');
        }
      }
    } catch (e) {
      _showError(_getErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // Clear ALL errors first
    setState(() {
      _formError = null;
      _errorMessage = null;
      _termsError = null;
    });
    if (!_termsAccepted) {
      setState(() {
        _termsError = 'Please accept Terms of Service and Privacy Policy';
      });
      return;
    }
    // Network check first
    try {
      final hasNetwork = await NetworkService().isConnected;
      if (!hasNetwork) {
        if (mounted) {
          setState(() {
            _formError = 'Connect to internet for Google sign-in';
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = 'Unable to check network connection';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.signInWithGoogle();

      if (success && mounted) {
        _showSuccess('Welcome to KoFund!');

        // ⭐ CHECK FOR MISSING PHONE NUMBER
        final currentUser = authProvider.user;
        final needsPhone =
            currentUser?.phoneNumber == null ||
            currentUser!.phoneNumber!.isEmpty;

        if (needsPhone) {
          debugPrint('⚠️ Missing phone number. Redirecting to SetPhoneScreen.');
          final codeParam = (_cachedInviteCode != null && _cachedInviteCode!.isNotEmpty) ? '?code=$_cachedInviteCode' : '';
          context.go('${RouteNames.setPhone}$codeParam');
          return; // SetPhoneScreen will handle the rest of the flow
        }

        if (_cachedInviteCode != null) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          _navigateToJoinCommunityWithInvite();
        } else {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          context.go('/splash');
        }
      } else {
        // Check provider error - ONLY show if not a cancellation
        final providerError = authProvider.error ?? '';
        if (providerError.isNotEmpty && !_isCancellationError(providerError)) {
          if (mounted) {
            _showError(providerError);
          }
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      // Don't show cancellation errors - just silently ignore
      if (!_isCancellationError(errorStr)) {
        final errorMsg = _getGoogleErrorMessage(e);
        if (errorMsg.isNotEmpty) {
          if (mounted) {
            _showError(errorMsg);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToForgotPassword() {
    context.push(RouteNames.forgotPassword);
  }

  bool _isCancellationError(String error) {
    if (error.isEmpty) return false;

    final errorLower = error.toLowerCase();

    // Common cancellation patterns
    final cancellationPatterns = [
      'cancelled',
      'canceled',
      'popup closed',
      'popup-closed',
      'sign-in was cancelled',
      'signin was cancelled',
      'google signin was cancelled',
      'Google sign-in was cancelled', // This is your specific error
      'popup-closed-by-user',
      'cancelled-popup-request',
      'access_denied',
      'user cancelled',
      'user canceled',
      'the user cancelled',
      'exception: signin cancelled',
      'exception: google signin was cancelled',
      'signin cancelled', // Add more variations
      'sign-in cancelled',
      'google sign-in cancelled',
    ];

    for (final pattern in cancellationPatterns) {
      if (errorLower.contains(pattern)) {
        debugPrint('Detected cancellation error: $error');
        return true;
      }
    }

    return false;
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      // First check for cancellations
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        return ''; // Return empty string for cancellation
      }

      // Handle other errors
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many login attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email but different sign-in method.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }

    // Check for cancellation in string
    final errorString = error.toString();
    if (_isCancellationError(errorString)) {
      return ''; // Return empty string for cancellation
    }

    if (errorString.contains('signInWithPopup') ||
        errorString.contains('signInWithRedirect')) {
      return 'Google sign-in is not supported on this device. Please use email/password instead.';
    }

    return 'An error occurred: $error';
  }

  String _getGoogleErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      // Check for cancellations FIRST
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'access_denied' ||
          error.message?.toLowerCase().contains('cancelled') == true ||
          error.message?.toLowerCase().contains('canceled') == true) {
        return ''; // Return empty string for cancellation
      }

      // Handle other errors
      switch (error.code) {
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email but different sign-in method.';
        case 'invalid-credential':
          return 'Invalid credentials. Please try again.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'user-not-found':
          return 'No account found. Please sign up first.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'too-many-requests':
          return 'Too many login attempts. Please try again later.';
        default:
          return 'Google sign-in failed: ${error.message}';
      }
    }

    // Check for cancellation in string
    final errorString = error.toString();
    if (_isCancellationError(errorString)) {
      return ''; // Return empty string for cancellation
    }

    if (errorString.contains('signInWithPopup') ||
        errorString.contains('signInWithRedirect')) {
      return 'Google sign-in is not supported on this device. Please use email/password instead.';
    }

    // For non-cancellation errors, return a user-friendly message
    if (errorString.isNotEmpty) {
      return 'Google sign-in failed. Please try again.';
    }

    return '';
  }

  String _cleanAuthErrorMessage(String message) {
    final lower = message.toLowerCase();
    
    if (lower.contains('invalid-credential') || 
        lower.contains('invalid_login_credentials') ||
        lower.contains('invalid credential') || 
        lower.contains('supplied auth credentials') ||
        lower.contains('supplied auth credential') ||
        lower.contains('bad-credential') || 
        lower.contains('wrong-password') ||
        lower.contains('incorrect password')) {
      return 'Incorrect email or password. Please try again.';
    }
    
    if (lower.contains('user-not-found') || 
        lower.contains('no user found') ||
        lower.contains('user not found')) {
      return 'No account found with this email.';
    }
    
    if (lower.contains('email-already-in-use') || 
        lower.contains('email already exists') ||
        lower.contains('email-already-exists')) {
      return 'This email is already registered. Please sign in or use a different email.';
    }

    if (lower.contains('weak-password')) {
      return 'The password is too weak. Please use a stronger password.';
    }

    if (lower.contains('invalid-email') || 
        lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    if (lower.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }

    if (lower.contains('too-many-requests') || 
        lower.contains('too many requests') ||
        lower.contains('blocked all requests')) {
      return 'Too many attempts. Please try again later.';
    }

    if (lower.contains('network-request-failed') || 
        lower.contains('network error') ||
        lower.contains('network_error') ||
        lower.contains('connectivity') ||
        lower.contains('internet')) {
      return 'Network error. Please check your internet connection.';
    }

    if (lower.contains('channel-error')) {
      return 'Please fill in all required fields.';
    }
    
    if (lower.contains('firebase') || lower.contains('auth/') || lower.contains('exception:')) {
      return 'Authentication failed. Please check your details and try again.';
    }

    return message;
  }

  void _showError(String message) {
    if (message.isEmpty || _isCancellationError(message)) return;
    final cleanMsg = _cleanAuthErrorMessage(message);
    SnackbarHelper.showError(context, cleanMsg);
  }

  void _showSuccess(String message) {
    SnackbarHelper.showSuccess(context, message);
  }

  void _clearError() => setState(() => _errorMessage = null);

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool showObscureToggle = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 100,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    final List<TextInputFormatter> formatters = [
      if (inputFormatters != null) ...inputFormatters,
      LengthLimitingTextInputFormatter(maxLength),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface(context) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText && _obscurePassword,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 15,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 20, right: 12),
                child: Icon(
                  icon,
                  color: AppColors.primary(context),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              suffixIcon: showObscureToggle
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: AppColors.textTertiary(context),
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    )
                  : null,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
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
                  color: AppColors.primary(context).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (_) {
              setState(() {
                if (controller == _emailController) _emailError = null;
                if (controller == _passwordController) _passwordError = null;
                _formError = null;
              });
            },
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 6),
            child: Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 0),
              child: Transform.translate(
                offset: const Offset(-4, 0),
                child: Transform.scale(
                  scale: 0.9,
                  child: Checkbox(
                    value: _termsAccepted,
                    onChanged: (value) {
                      setState(() {
                        _termsAccepted = value ?? false;
                        _termsError = null;
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    fillColor: WidgetStateProperty.resolveWith<Color?>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary(context);
                      }
                      return null;
                    }),
                    checkColor: Colors.white,
                    overlayColor: WidgetStateProperty.resolveWith<Color?>((
                      Set<WidgetState> states,
                    ) {
                      return AppColors.primary(context).withOpacity(0.1);
                    }),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(-4, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _termsAccepted = !_termsAccepted;
                      _termsError = null;
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 24),
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppColors.textSecondary(context),
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final url = Uri.parse('$_externalWebsiteUrl/terms-of-service');
                                try {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  debugPrint('Could not launch $url: $e');
                                }
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final url = Uri.parse('$_externalWebsiteUrl/privacy-policy');
                                try {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  debugPrint('Could not launch $url: $e');
                                }
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_termsError != null)
          Transform.translate(
            offset: const Offset(-4, 0),
            child: Container(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(
                _termsError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInviteBanner() {
    if (_cachedInviteCode == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppColors.primary(context).withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 18, color: AppColors.primary(context)),
          const SizedBox(width: 8),
          Text(
            'Invite code: ',
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
          ),
          Text(
            _cachedInviteCode!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary(context),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.primary(context)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _cachedInviteCode!));
              SnackbarHelper.showInfo(context, 'Copied');
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary(context)),
            onPressed: () {
              unawaited(_clearPendingInviteCode());
              setState(() => _cachedInviteCode = null);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final isLoading = authProvider.isLoading || _isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
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
                          const SizedBox(height: 20),
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
                              'Welcome back',
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
                              _cachedInviteCode != null
                                  ? 'Sign in to join the community'
                                  : 'Sign in to your account',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 15,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Form Errors
                          if (_formError != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _formError!,
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Inputs
                          _buildInputField(
                            controller: _emailController,
                            label: 'Email Address *',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            maxLength: 100,
                            errorText: _emailError,
                          ),
                          const SizedBox(height: 14),

                          _buildInputField(
                            controller: _passwordController,
                            label: 'Password *',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                            showObscureToggle: true,
                            maxLength: 128,
                            errorText: _passwordError,
                          ),

                          const SizedBox(height: 10),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLoading ? null : _navigateToForgotPassword,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Terms and Conditions
                          _buildTermsCheckbox(),

                          const SizedBox(height: 20),

                          // Sign In Button
                          FutureBuilder<bool>(
                            future: NetworkService().isConnected,
                            builder: (context, futureSnapshot) {
                              return StreamBuilder<bool>(
                                stream: NetworkService().onConnectionChanged,
                                builder: (context, streamSnapshot) {
                                  final bool currentIsOnline = streamSnapshot.hasData
                                      ? streamSnapshot.data!
                                      : (futureSnapshot.hasData
                                            ? futureSnapshot.data!
                                            : true);

                                  final bool isDisabled = isLoading || !currentIsOnline;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(100),
                                          boxShadow: [
                                            if (!isDisabled)
                                              BoxShadow(
                                                color: AppColors.primary(context).withOpacity(0.25),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: isDisabled ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary(context),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: AppColors.primary(context).withOpacity(0.5),
                                            disabledForegroundColor: Colors.white70,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                          ),
                                          child: isLoading
                                              ? const SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      currentIsOnline
                                                          ? Icons.arrow_forward_rounded
                                                          : Icons.wifi_off,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      currentIsOnline
                                                          ? (_cachedInviteCode != null
                                                                ? 'Sign In & Join Community'
                                                                : 'Sign In')
                                                          : 'Offline',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      if (!currentIsOnline)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8, left: 16),
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.info_outline_rounded,
                                                size: 14,
                                                color: Colors.redAccent,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Connect to internet to login',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
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

                          // Google Sign-In Button
                          FutureBuilder<bool>(
                            future: NetworkService().isConnected,
                            builder: (context, futureSnapshot) {
                              return StreamBuilder<bool>(
                                stream: NetworkService().onConnectionChanged,
                                builder: (context, streamSnapshot) {
                                  final isOnline = streamSnapshot.hasData
                                      ? streamSnapshot.data!
                                      : (futureSnapshot.hasData
                                            ? futureSnapshot.data!
                                            : true);
                                  final isDisabled = isLoading || !isOnline;

                                  return SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: isDisabled ? null : _signInWithGoogle,
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: AppColors.border(context),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        backgroundColor: isDark ? AppColors.surface(context) : Colors.white,
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/logos/google_logo.png',
                                            height: 22,
                                            width: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            isOnline
                                                ? (_cachedInviteCode != null
                                                      ? 'Join with Google'
                                                      : 'Continue with Google')
                                                : 'Offline',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isOnline
                                                  ? AppColors.textPrimary(context)
                                                  : AppColors.textPrimary(context).withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Create Account
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Don\'t have an account? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          context.go('/register');
                                        },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Create one',
                                    style: TextStyle(
                                      color: AppColors.primary(context),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          _buildInviteBanner(),
                          const SizedBox(height: 12),
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
    );
  }
}

void unawaited(Future<void> future) {}
