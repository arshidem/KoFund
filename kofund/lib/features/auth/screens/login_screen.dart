import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/core/constants/app_colors.dart'; // Add this import
import '../providers/app_auth_provider.dart';
import 'register_screen.dart';
import 'splash_screen.dart';
import 'verification_pending_screen.dart';
import 'forgot_password_screen.dart';
import 'package:kofund/routing/route_names.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters long');
      return;
    }

    if (password.length > 128) {
      _showError('Password cannot exceed 128 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.signIn(
        email: email,
        password: password,
      );

      if (success && mounted) {
        _showSuccess('Login successful!');
        Navigator.pushReplacementNamed(context, RouteNames.splash);
      } else if (mounted) {
        if (authProvider.shouldNavigateToVerification) {
          _showError('Please verify your email to continue.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationPendingScreen(
                email: authProvider.currentUserEmail ?? email,
              ),
            ),
          );
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.signInWithGoogle();

      if (success && mounted) {
        _showSuccess('Welcome to KoFund!');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SplashScreen()),
        );
      } else {
        _showError(authProvider.error ?? 'Google sign-in was cancelled');
      }
    } catch (e) {
      _showError(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordScreen(),
      ),
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
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
        case 'popup-closed-by-user':
          return 'Sign-in was cancelled.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    
    if (error.toString().contains('signInWithPopup') || 
        error.toString().contains('signInWithRedirect')) {
      return 'Google sign-in is not supported on this device. Please use email/password instead.';
    }
    
    return error.toString();
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _clearError() => setState(() => _errorMessage = null);

Widget _buildInputField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  bool obscureText = false,
  bool? showObscureToggle,
  TextInputType keyboardType = TextInputType.text,
  int maxLength = 100,
  String? Function(String?)? validator,
  List<TextInputFormatter>? inputFormatters,
}) {
  // Combine custom formatters with length limiting formatter
  List<TextInputFormatter> combinedFormatters = [];
  
  if (inputFormatters != null) {
    combinedFormatters.addAll(inputFormatters);
  }
  
  // Add length limiting formatter (this won't show counter)
  combinedFormatters.add(LengthLimitingTextInputFormatter(maxLength));

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context),
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscureText && _obscurePassword,
        keyboardType: keyboardType,
        inputFormatters: combinedFormatters,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors.primary(context),
            size: 20,
          ),
          suffixIcon: showObscureToggle == true
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary(context),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primary(context),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: AppColors.surface(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
        ),
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 14,
        ),
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 6),
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
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(context).withOpacity(0.3),
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

              // Form Title
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
                  'Sign in to your account',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Error Messages
              if (authProvider.error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authProvider.error!,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Form Fields
              _buildInputField(
                controller: _emailController,
                label: 'Email Address *',
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                maxLength: 100,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),

              _buildInputField(
                controller: _passwordController,
                label: 'Password *',
                hint: 'Enter your password',
                icon: Icons.lock_outline,
                obscureText: true,
                showObscureToggle: true,
                maxLength: 128,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
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

              const SizedBox(height: 20),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  icon: Image.asset(
                    'assets/logos/google_logo.png',
                    height: 20,
                    width: 20,
                  ),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  onPressed: isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppColors.surface(context),
                  ),
                ),
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
                                  builder: (context) => const RegisterScreen(),
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
            ],
          ),
        ),
      ),
    );
  }
}