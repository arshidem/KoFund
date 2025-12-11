// lib/features/community/screens/tabs/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/profile/screens/profile_screen.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../pending_approval_screen.dart';
import '../join_community_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Add a small delay to ensure context is available
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();

    // Show loading while checking initial auth status
    if (_isCheckingAuth) {
      return const LoadingIndicator(message: 'Loading profile...');
    }

    // 🧩 1️⃣ If the user is logged out
    if (authProvider.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      });
      return const LoadingIndicator(message: 'Redirecting to login...');
    }

    // 🧩 2️⃣ If the user hasn't joined a community
    if (authProvider.user?.communityId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const JoinCommunityScreen()),
          );
        }
      });
      return const LoadingIndicator(message: 'Redirecting to community...');
    }

    // 🧩 3️⃣ If user is not yet approved
    if (authProvider.user?.isApproved == false) {
      return const PendingApprovalScreen();
    }

    // 🧩 4️⃣ Otherwise, show the profile screen
    return const ProfileScreen();
  }
}