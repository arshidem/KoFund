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
import 'package:kofund/features/profile/screens/settings/terms_of_service_screen.dart';
import 'package:kofund/features/profile/screens/settings/privacy_policy_screen.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_styles.dart';

class LoginScreen extends StatefulWidget {
  final String? pendingInviteCode;
  const LoginScreen({super.key, this.pendingInviteCode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JoinCommunityScreen(inviteCode: _cachedInviteCode),
      ),
    );
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
      final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      // Clear previous provider errors
      _authProvider.clearError();
      
      final success = await _authProvider.signIn(
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
          Navigator.pushReplacementNamed(context, RouteNames.splash);
        }
      } else if (mounted) {
        if (_authProvider.shouldNavigateToVerification) {
          _showError('Please verify your email to continue.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationPendingScreen(
                email: _authProvider.currentUserEmail ?? email,
              ),
            ),
          );
        } else {
          _showError(_authProvider.error ?? 'Login failed. Please try again.');
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
      final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await _authProvider.signInWithGoogle();

      if (success && mounted) {
        _showSuccess('Welcome to KoFund!');

        // ⭐ CHECK FOR MISSING PHONE NUMBER
        final currentUser = _authProvider.user;
        final needsPhone =
            currentUser?.phoneNumber == null ||
            currentUser!.phoneNumber!.isEmpty;

        if (needsPhone) {
          debugPrint('⚠️ Missing phone number. Redirecting to SetPhoneScreen.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SetPhoneScreen(pendingInviteCode: _cachedInviteCode),
            ),
          );
          return; // SetPhoneScreen will handle the rest of the flow
        }

        if (_cachedInviteCode != null) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          _navigateToJoinCommunityWithInvite();
        } else {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SplashScreen()),
          );
        }
      } else {
        // Check provider error - ONLY show if not a cancellation
        final providerError = _authProvider.error ?? '';
        if (providerError.isNotEmpty && !_isCancellationError(providerError)) {
          if (mounted) {
            setState(() {
              _errorMessage = providerError;
            });
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
            setState(() {
              _errorMessage = errorMsg;
            });
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
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

  void _showError(String message) {
    if (message.isEmpty || _isCancellationError(message)) return;

    final lowerMessage = message.toLowerCase();
    setState(() {
      if (lowerMessage.contains('email') || lowerMessage.contains('user-not-found')) {
        _emailError = message;
      } else if (lowerMessage.contains('password')) {
        _passwordError = message;
      } else {
        _formError = message; // General form/network errors
      }
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
    );
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

    return TextFormField(
      controller: controller,
      obscureText: obscureText && _obscurePassword,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: label, // ⭐ FLOATING LABEL
        labelStyle: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColors.primary(context),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary(context), size: 20),
        suffixIcon: showObscureToggle
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
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
          borderSide: BorderSide(color: AppColors.primary(context), width: 2),
        ),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 12, height: 1.2),
      ),
      onChanged: (_) {
        setState(() {
          if (controller == _emailController) _emailError = null;
          if (controller == _passwordController) _passwordError = null;
          _formError = null;
        });
      },
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
            // Checkbox with individual control
            Container(
              margin: const EdgeInsets.only(
                right: 0,
              ), // ⭐ Control checkbox right spacing
              child: Transform.translate(
                offset: const Offset(
                  -4,
                  0,
                ), // ⭐ Move checkbox horizontally/vertically
                child: Transform.scale(
                  scale: 0.8, // ⭐ Control checkbox size
                  child: Checkbox(
                    value: _termsAccepted,
                    onChanged: (value) {
                      setState(() {
                        _termsAccepted = value ?? false;
                        _termsError = null;
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall / 2,
                      ), // 4
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // ⭐ Control colors
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
                      return AppColors.primary(context).withValues(alpha: 0.1);
                    }),
                  ),
                ),
              ),
            ),

            // Text with individual control
            Expanded(
              child: Transform.translate(
                offset: const Offset(
                  -6,
                  0,
                ), // ⭐ Move text horizontally/vertically
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _termsAccepted = !_termsAccepted;
                      _termsError = null;
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 24, // ⭐ Control minimum touch area height
                    ),
                    padding: EdgeInsets.zero, // ⭐ Zero container padding
                    margin: EdgeInsets.zero, // ⭐ Zero container margin
                    alignment: Alignment.centerLeft, // ⭐ Force left alignment
                    child: RichText(
                      textAlign: TextAlign.left, // ⭐ Force text alignment
                      textWidthBasis: TextWidthBasis.parent,
                      overflow: TextOverflow.visible,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 10, // ⭐ Control text size
                          height: 1.2, // ⭐ Control line height
                          color: AppColors.textPrimary(context),
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationThickness:
                                  1.5, // ⭐ Control underline thickness
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TermsOfServiceScreen(),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationThickness:
                                  1.5, // ⭐ Control underline thickness
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PrivacyPolicyScreen(),
                                  ),
                                );
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

        // Error message with individual control
        if (_termsError != null)
          Transform.translate(
            offset: const Offset(-6, 0), // ⭐ Position error message
            child: Container(
              padding: const EdgeInsets.only(left: 8, top: 4),
              margin: EdgeInsets.zero,
              child: Text(
                _termsError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ⭐ MINIMAL: Build invite notification banner
  Widget _buildInviteBanner() {
    if (_cachedInviteCode == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'Invite code: ',
            style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
          ),
          Text(
            _cachedInviteCode!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.copy, size: 16, color: Colors.blue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _cachedInviteCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.grey),
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
    final _authProvider = Provider.of<AppAuthProvider>(context);
    final isLoading = _authProvider.isLoading || _isLoading;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppStyles.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo and Header
              Center(
                child: Column(
                  children: [
                    // Logo with rounded background
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.primary(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(
                              context,
                            ).withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/logos/KoFund.png',
                            height: 80,
                            width: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'KoFund',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ⭐ NEW: Invite Notification Banner

              // Form Ttitle
              Center(
                child: Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  _cachedInviteCode != null
                      ? 'Sign in to join the community'
                      : 'Sign in to your account',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Note: Top-level error container removed as errors are now routed to specific fields
              
              // Display network/form errors (using formError for general messaging)
              if (_formError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formError!,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              _buildInputField(
                controller: _emailController,
                label: 'Email Address *',
                // hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                maxLength: 100,
                errorText: _emailError, // Pass error here
              ),
              const SizedBox(height: 16),

              // Password field
              _buildInputField(
                controller: _passwordController,
                label: 'Password *',
                // hint: 'Enter your password',
                icon: Icons.lock_outline,
                obscureText: true,
                showObscureToggle: true,
                maxLength: 128,
                errorText: _passwordError, // Pass error here
              ),

              // Forgot Password Button
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
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary(context),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              // Terms checkbox
              _buildTermsCheckbox(),
              const SizedBox(height: 20),

              // Login Button
              // Replace your current login button with this:
              // Network-aware Login Button (SAME PATTERN AS CREATE COMMUNITY)
              // Login Button - Fixed
              FutureBuilder<bool>(
                future: NetworkService().isConnected,
                builder: (context, futureSnapshot) {
                  final bool isOnlineFromFuture = futureSnapshot.data ?? true;

                  return StreamBuilder<bool>(
                    stream: NetworkService().onConnectionChanged,
                    builder: (context, streamSnapshot) {
                      // ⭐ REMOVE initialData and use conditional logic
                      final bool currentIsOnline = streamSnapshot.hasData
                          ? streamSnapshot.data!
                          : (futureSnapshot.hasData
                                ? futureSnapshot.data!
                                : true);

                      final bool isDisabled = _isLoading || !currentIsOnline;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isDisabled ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(context),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primary(
                                  context,
                                ).withValues(alpha: 0.5),
                                disabledForegroundColor: Colors.white70,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          currentIsOnline
                                              ? Icons.login
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
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Network status message
                          if (!currentIsOnline)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.info_outline,
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
              const SizedBox(height: 20),

              // Divider
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
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

              const SizedBox(height: 20),

              // Google Sign-In Button
              // Google Sign-In Button - Fixed
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
                      final isDisabled = _isLoading || !isOnline;

                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          icon: Image.asset(
                            'assets/logos/google_logo.png',
                            height: 20,
                            width: 20,
                          ),
                          label: Text(
                            isOnline
                                ? (_cachedInviteCode != null
                                      ? 'Join with Google'
                                      : 'Continue with Google')
                                : 'Offline',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isOnline
                                  ? AppColors.textPrimary(context)
                                  : AppColors.textPrimary(
                                      context,
                                    ).withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: isDisabled ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isOnline
                                  ? AppColors.border(context)
                                  : AppColors.border(
                                      context,
                                    ).withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            backgroundColor: AppColors.surface(context),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              // Sign Up Link
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
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(
                                    pendingInviteCode: _cachedInviteCode,
                                  ),
                                ),
                              );
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
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildInviteBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

// ⭐ NEW: Add unawaited helper function
void unawaited(Future<void> future) {}





