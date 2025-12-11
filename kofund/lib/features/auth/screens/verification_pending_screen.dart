// lib/features/auth/screens/verification_pending_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../providers/app_auth_provider.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class VerificationPendingScreen extends StatefulWidget {
  final String email;
  
  const VerificationPendingScreen({super.key, required this.email});

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  bool _isResending = false;
  bool _isChecking = false;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _startAutoVerificationCheck();
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  // Auto-check verification status every 5 seconds
  void _startAutoVerificationCheck() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkVerificationStatus();
    });
  }

  Future<void> _checkVerificationStatus() async {
    if (_isChecking) return;
    
    setState(() => _isChecking = true);
    
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null && currentUser.emailVerified && mounted) {
        // Email verified - stop timer and navigate to app
        _verificationTimer?.cancel();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to splash screen to continue normal flow
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
        );
      }
    } catch (e) {
      print('Error checking verification: $e');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final success = await authProvider.resendVerificationEmail();
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Failed to resend email'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    if (mounted) {
      setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _signOut,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView( // Added SingleChildScrollView to prevent overflow
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                        MediaQuery.of(context).padding.top - 
                        kToolbarHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 100,
                  color: Colors.orange[700],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We sent a verification link to:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please check your email and click the verification link to activate your account. '
                  'This screen will automatically update once your email is verified.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Auto-check status indicator - Fixed layout
                Container(
                  height: 80, // Fixed height to prevent layout shifts
                  child: _isChecking 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Checking verification status...',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '⏳ Automatically checking for verification...',
                              style: TextStyle(fontSize: 14, color: Colors.green),
                            ),
                          ],
                        ),
                ),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isResending ? null : _resendVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                    ),
                    child: _isResending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Resend Verification Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _signOut,
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 32), // Reduced space
                const Column(
                  children: [
                    Icon(Icons.info_outline, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      "Didn't receive the email?",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "• Check your spam folder\n• Make sure you entered the correct email\n• Wait a few minutes and try again",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}