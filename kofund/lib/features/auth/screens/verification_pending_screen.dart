// lib/features/auth/screens/verification_pending_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_auth_provider.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'package:flutter/services.dart';
class VerificationPendingScreen extends StatefulWidget {
  final String email;
  final String? pendingInviteCode;
  
  const VerificationPendingScreen({
    super.key, 
    required this.email,
    this.pendingInviteCode,
  });

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
    _checkForPendingInvite();
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForPendingInvite() async {
    if (widget.pendingInviteCode != null && widget.pendingInviteCode!.isNotEmpty) {
      debugPrint('🎯 Verification screen has pending invite: ${widget.pendingInviteCode}');
    }
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
        // Email verified - stop timer
        _verificationTimer?.cancel();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // ⭐ NEW: Check if we have a pending invite code
        if (widget.pendingInviteCode != null) {
          debugPrint('✅ Email verified with invite code, saving to storage');
          
          // Save invite code for after splash screen
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_invite_code', widget.pendingInviteCode!);
          
          // Navigate to splash screen which will handle the invite
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SplashScreen(
                deepLinkInviteCode: widget.pendingInviteCode,
              ),
            ),
          );
        } else {
          // Check storage for any pending invites
          final prefs = await SharedPreferences.getInstance();
          final storedInviteCode = prefs.getString('pending_invite_code');
          
          if (storedInviteCode != null && storedInviteCode.isNotEmpty) {
            debugPrint('📋 Found stored invite code after verification: $storedInviteCode');
            
            // Navigate to splash screen with stored invite
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SplashScreen(
                  deepLinkInviteCode: storedInviteCode,
                ),
              ),
            );
          } else {
            // Normal flow - no invite
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SplashScreen()),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking verification: $e');
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

Widget _buildInviteBanner() {
  if (widget.pendingInviteCode == null) return const SizedBox.shrink();

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
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
      ],
    ),
  );
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
        child: SingleChildScrollView(
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
                
                // ⭐ ADD: Invite Banner
                
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
                Text(
                  widget.pendingInviteCode != null
                      ? 'Please verify your email to join the community. '
                        'This screen will automatically update once your email is verified.'
                      : 'Please check your email and click the verification link to activate your account. '
                        'This screen will automatically update once your email is verified.',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                                _buildInviteBanner(),

                const SizedBox(height: 32),
                
                // Auto-check status indicator
                Container(
                  height: 80,
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
                const SizedBox(height: 32),
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