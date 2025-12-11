// lib/features/community/screens/tabs/contributions_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/contributions/screens/all_contribution_screen.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../pending_approval_screen.dart';
import '../join_community_screen.dart';

class ContributionsTab extends StatefulWidget {
  const ContributionsTab({super.key});

  @override
  State<ContributionsTab> createState() => _ContributionsTabState();
}

class _ContributionsTabState extends State<ContributionsTab> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final authProvider = context.read<AppAuthProvider>();
    
    // You can load contributions-specific data here if needed
    // For example: pre-load contributions, programs, etc.
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();

    // 🧩 1️⃣ If the user is logged out (e.g., deleted account or signed out)
    if (authProvider.user == null) {
      // Avoid multiple navigations
      Future.microtask(() {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      });
      return const LoadingIndicator(message: 'Redirecting to login...');
    }

    // 🧩 2️⃣ If the user hasn't joined a community
    if (authProvider.user?.communityId == null) {
      Future.microtask(() {
        if (mounted) {
          Navigator.pushNamed(context, '/join-community');
        }
      });
      return const LoadingIndicator(message: 'Redirecting to community...');
    }

    // 🧩 3️⃣ If user is not yet approved
    if (authProvider.user?.isApproved == false) {
      return const PendingApprovalScreen();
    }

    // 🧩 4️⃣ Otherwise, show the contributions screen
    return const AllContributionsScreen();
  }
}