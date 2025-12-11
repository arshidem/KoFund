// lib/features/community/screens/tabs/dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/dashboard/screens/dashboard_screen.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../pending_approval_screen.dart';

// lib/features/community/screens/tabs/dashboard_tab.dart
class DashboardTab extends StatefulWidget {
  final VoidCallback? onNavigateToMembers;
  
  const DashboardTab({super.key, this.onNavigateToMembers});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();

    // 1️⃣ User not logged in
    if (authProvider.user == null) {
      Future.microtask(() {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      });
      return const LoadingIndicator(message: 'Redirecting to login...');
    }

    // 2️⃣ User has not joined any community
    if (authProvider.user?.communityId == null) {
      Future.microtask(() {
        if (mounted) {
          Navigator.pushNamed(context, '/join-community');
        }
      });
      return const LoadingIndicator(message: 'Joining community...');
    }

    // 3️⃣ User is not approved
    if (authProvider.user!.isApproved == false) {
      return const PendingApprovalScreen();
    }

    // 4️⃣ User approved → show your dashboard
    return DashboardScreen(onNavigateToMembers: widget.onNavigateToMembers); // ✅ FIXED
  }
}