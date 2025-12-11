// lib/features/auth/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_auth_provider.dart';
import 'login_screen.dart';
import 'verification_pending_screen.dart'; // Add this import
import 'splash_screen.dart'; // ✅ ADDED
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _register() async {
  if (_nameController.text.isEmpty ||
      _emailController.text.isEmpty ||
      _phoneController.text.isEmpty ||
      _passwordController.text.isEmpty) {
    _showError('Please fill in all fields');
    return;
  }

  if (_passwordController.text.length < 6) {
    _showError('Password must be at least 6 characters long');
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (success && mounted) {
      _showSuccess('Account created! Please verify your email.');
      
      // ✅ FIXED: Navigate to verification screen with current user context
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationPendingScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else {
      // If registration failed but user exists (email already registered)
      if (authProvider.user != null && authProvider.needsEmailVerification) {
        // User exists but needs verification - navigate to verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationPendingScreen(
              email: authProvider.currentUserEmail ?? _emailController.text.trim(),
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.signInWithGoogle();

     // In _signInWithGoogle method - around line 130
if (success && mounted) {
  _showSuccess('Google sign-up successful!');
  await Future.delayed(const Duration(seconds: 1));
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => SplashScreen()), // ✅ REMOVED const
  );
} else {
        _showError(authProvider.error ?? 'Google sign-up was cancelled');
      }
    } catch (e) {
      _showError(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
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
        case 'popup-closed-by-user':
          return 'Sign-in was cancelled.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    
    // Handle platform-specific errors
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
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearError() => setState(() => _errorMessage = null);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    
    // Use provider's loading state if available, otherwise use local state
    final isLoading = authProvider.isLoading || _isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.person_add, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join the community today',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              // Show provider errors too
              if (authProvider.error != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Enter your full name',
                ),
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  hintText: 'Enter your email',
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: 'Enter your phone number',
                ),
                keyboardType: TextInputType.phone,
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  hintText: 'Create a password (min 6 characters)',
                ),
                onChanged: (_) => _clearError(),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider(thickness: 1)),
                ],
              ),
              const SizedBox(height: 16),

              // Google Sign-Up Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: Image.asset(
                    'assets/logos/google_logo.png',
                    height: 24,
                    width: 24,
                  ),
                  label: const Text(
                    'Sign up with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                child: const Text(
                  'Already have an account? Sign in',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}