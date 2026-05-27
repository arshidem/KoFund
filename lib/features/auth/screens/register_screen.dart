// lib/features/auth/screens/register_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../providers/app_auth_provider.dart';
import 'login_screen.dart';
import 'verification_pending_screen.dart';
import 'splash_screen.dart';
import 'package:kofund/core/services/network_service.dart';
import 'package:kofund/features/profile/screens/settings/terms_of_service_screen.dart';
import 'package:kofund/features/profile/screens/settings/privacy_policy_screen.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class RegisterScreen extends StatefulWidget {
  final String? pendingInviteCode;
  const RegisterScreen({super.key, this.pendingInviteCode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showInviteNotification = false;
  bool _termsAccepted = false;

  String? _errorMessage;
  String? _nnameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _termsError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    // Check if we have a pending invite
    if (widget.pendingInviteCode != null && widget.pendingInviteCode!.isNotEmpty) {
      _showInviteNotification = true;
    }
  }

Widget _buildInviteBanner() {
  if (widget.pendingInviteCode == null) return const SizedBox.shrink();

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
    ),
    child: Row(
      children: [
        Icon(Icons.link, size: 16, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          'Invite: ',
          style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
        ),
        Text(
          widget.pendingInviteCode!,
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
            Clipboard.setData(ClipboardData(text: widget.pendingInviteCode!));
            SnackbarHelper.showInfo(context, 'Copied');
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _register() async {
  // Clear previous errors
  setState(() {
    _nnameError = null;
    _emailError = null;
    _phoneError = null;
    _passwordError = null;
    _formError = null;
    _errorMessage = null;
    _termsError = null;
  });

  // Check terms acceptance
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
        _formError = 'Connect to internet to register';
      });
      return;
    }
  } catch (e) {
    setState(() {
      _formError = 'Unable to check network connection';
    });
    return;
  }

  // Trim inputs
  final name = _nameController.text.trim();
  final email = _emailController.text.trim();
  final phone = _phoneController.text.trim();
  final password = _passwordController.text.trim();

  bool hasError = false;

  // Name validation
  if (name.isEmpty) {
    _nnameError = 'Name is required';
    hasError = true;
  } else if (name.length < 2) {
    _nnameError = 'Name must be at least 2 characters';
    hasError = true;
  } else if (name.length > 50) {
    _nnameError = 'Name cannot exceed 50 characters';
    hasError = true;
  } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
    _nnameError = 'Name can only contain letters and spaces';
    hasError = true;
  }

  // Email validation
  if (email.isEmpty) {
    _emailError = 'Email is required';
    hasError = true;
  } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    _emailError = 'Enter a valid email';
    hasError = true;
  }

  // Phone validation
  final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.isEmpty) {
    _phoneError = 'Phone number is required';
    hasError = true;
  } else if (phoneDigits.length != 10) {
    _phoneError = 'Phone number must be 10 digits';
    hasError = true;
  } else if (phoneDigits.startsWith('0')) {
    _phoneError = 'Phone number cannot start with 0';
    hasError = true;
  }

  // Password validation
  if (password.isEmpty) {
    _passwordError = 'Password is required';
    hasError = true;
  } else if (password.length < 6) {
    _passwordError = 'Minimum 6 characters';
    hasError = true;
  } else if (password.length > 128) {
    _passwordError = 'Password cannot exceed 128 characters';
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
    // Clear any previous provider errors
    authProvider.clearError();
    
    final success = await authProvider.signUp(
      email: email,
      password: password,
      name: name,
      phone: phoneDigits,
    );

    if (success && mounted) {
      _showSuccess('Account created successfully! Please verify your email.');
      
      // Store invite code for after verification
      if (widget.pendingInviteCode != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_invite_code', widget.pendingInviteCode!);
        if (!mounted) return;
        debugPrint('💾 Saved invite code for after verification: ${widget.pendingInviteCode}');
      }
      
      // Navigate to verification screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationPendingScreen(
            email: email,
            pendingInviteCode: widget.pendingInviteCode,
          ),
        ),
      );
    } else {
      if (authProvider.user != null && authProvider.needsEmailVerification) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationPendingScreen(
              email: authProvider.currentUserEmail ?? email,
              pendingInviteCode: widget.pendingInviteCode,
            ),
          ),
        );
      } else {
        _showError(authProvider.error ?? 'Registration failed. Please try again.');
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

  // Check terms acceptance
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
      
      // Check if we have pending invite
      if (widget.pendingInviteCode != null) {
        debugPrint('✅ Google registration successful with invite code');
        
        // Store invite code
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        await prefs.setString('pending_invite_code', widget.pendingInviteCode!);
        if (!mounted) return;
        
        // Navigate to SplashScreen which will handle the invite
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SplashScreen(
              deepLinkInviteCode: widget.pendingInviteCode,
            ),
          ),
        );
      } else {
        // Normal flow
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
        );
      }
    } else {
      // Check if it's a cancellation error
      final providerError = authProvider.error ?? '';
      if (providerError.isNotEmpty && !_isCancellationError(providerError)) {
        _showError(providerError);
      }
    }
  } catch (e) {
    if (!_isCancellationError(e.toString())) {
      _showError(_getGoogleErrorMessage(e));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
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
    'Google sign-in was cancelled',
    'popup-closed-by-user',
    'cancelled-popup-request',
    'access_denied',
    'user cancelled',
    'user canceled',
    'the user cancelled',
    'exception: signin cancelled',
    'exception: google signin was cancelled',
    'signin cancelled',
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
    // Check for cancellations
    if (error.code == 'popup-closed-by-user' ||
        error.code == 'cancelled-popup-request') {
      return ''; // Return empty string for cancellation
    }
    
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email or sign in.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
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
      } else if (lowerMessage.contains('phone')) {
        _phoneError = message;
      } else if (lowerMessage.contains('name')) {
        _nnameError = message;
      } else {
        _formError = message; // Show non-field errors in formError container
      }
    });
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

  return TextFormField(
    controller: controller,
    obscureText: obscureText && _obscurePassword,
    keyboardType: keyboardType,
    inputFormatters: formatters,
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
      prefixIcon: Icon(
        icon,
        color: AppColors.primary(context),
        size: 20,
      ),
      suffixIcon: showObscureToggle
          ? IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
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
        borderSide: BorderSide(
          color: AppColors.primary(context),
          width: 2,
        ),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(
        fontSize: 12,
        height: 1.2,
      ),
    ),
    onChanged: (_) {
      setState(() {
        if (controller == _nameController) _nnameError = null;
        if (controller == _emailController) _emailError = null;
        if (controller == _phoneController) _phoneError = null;
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
            margin: const EdgeInsets.only(right: 0),
            child: Transform.translate(
              offset: const Offset(-4, 0),
              child: Transform.scale(
                scale: 0.8,
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
                  fillColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary(context);
                      }
                      return null;
                    },
                  ),
                  checkColor: Colors.white,
                  overlayColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      return AppColors.primary(context).withValues(alpha: 0.1);
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Text with individual control
          Expanded(
            child: Transform.translate(
              offset: const Offset(-6, 0),
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
                    minHeight: 24,
                  ),
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    textAlign: TextAlign.left,
                    textWidthBasis: TextWidthBasis.parent,
                    overflow: TextOverflow.visible,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
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
                            decorationThickness: 1.5,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TermsOfServiceScreen(),
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
                            decorationThickness: 1.5,
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
      
      // Error message for terms
      if (_termsError != null)
        Transform.translate(
          offset: const Offset(-6, 0),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final isLoading = authProvider.isLoading || _isLoading;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(context).withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipOval(
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

              // Form Ttitle
              Center(
                child: Text(
                  'Create Account',
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
                  widget.pendingInviteCode != null
                      ? 'Create account to join the community'
                      : 'Create your account to get started',
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
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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

              // Name field
              _buildInputField(
                controller: _nameController,
                label: 'Full Name *',
                icon: Icons.person_outline,
                maxLength: 25,
                errorText: _nnameError,
              ),
              const SizedBox(height: 16),

              // Email field
              _buildInputField(
                controller: _emailController,
                label: 'Email Address *',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                maxLength: 100,
                errorText: _emailError,
              ),
              const SizedBox(height: 16),

              // Phone field
              _buildInputField(
                controller: _phoneController,
                label: 'Phone Number *',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                errorText: _phoneError,
              ),
              const SizedBox(height: 16),

              // Password field
              _buildInputField(
                controller: _passwordController,
                label: 'Password *',
                icon: Icons.lock_outline,
                obscureText: true,
                showObscureToggle: true,
                maxLength: 128,
                errorText: _passwordError,
              ),

              const SizedBox(height: 16),

              // Terms checkbox
              _buildTermsCheckbox(),

              const SizedBox(height: 20),

              // Register Button (Network-aware)
              FutureBuilder<bool>(
                future: NetworkService().isConnected,
                builder: (context, futureSnapshot) {
                  final bool isOnlineFromFuture = futureSnapshot.data ?? true;
                  
                  return StreamBuilder<bool>(
                    stream: NetworkService().onConnectionChanged,
                    builder: (context, streamSnapshot) {
                      final bool currentIsOnline = streamSnapshot.hasData 
                          ? streamSnapshot.data! 
                          : (futureSnapshot.hasData ? futureSnapshot.data! : true);
                      
                      final bool isDisabled = _isLoading || !currentIsOnline;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isDisabled ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(context),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary(context).withValues(alpha: 0.5),
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          currentIsOnline ? Icons.person_add : Icons.wifi_off,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          currentIsOnline
                                              ? (widget.pendingInviteCode != null
                                                  ? 'Create Account & Join Community'
                                                  : 'Create Account')
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
                                    'Connect to internet to register',
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

              // Google Sign-Up Button (Network-aware)
              FutureBuilder<bool>(
                future: NetworkService().isConnected,
                builder: (context, futureSnapshot) {
                  return StreamBuilder<bool>(
                    stream: NetworkService().onConnectionChanged,
                    builder: (context, streamSnapshot) {
                      final isOnline = streamSnapshot.hasData
                          ? streamSnapshot.data!
                          : (futureSnapshot.hasData ? futureSnapshot.data! : true);
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
                                ? (widget.pendingInviteCode != null
                                    ? 'Join with Google'
                                    : 'Continue with Google')
                                : 'Offline',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isOnline 
                                  ? AppColors.textPrimary(context)
                                  : AppColors.textPrimary(context).withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: isDisabled ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isOnline 
                                  ? AppColors.border(context)
                                  : AppColors.border(context).withValues(alpha: 0.5),
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

              // Sign In Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
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
                                  builder: (context) => LoginScreen(
                                    pendingInviteCode: widget.pendingInviteCode,
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
                        'Sign in',
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






