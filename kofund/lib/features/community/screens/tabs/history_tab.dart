// lib/features/community/screens/tabs/history_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/history/screens/history_screen.dart';

import '../pending_approval_screen.dart';
import '../join_community_screen.dart';

class HistoryTab extends StatelessWidget { // ✅ Make it StatelessWidget
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();

    // 1️⃣ If user is logged out or auth reset -> send to login
    if (authProvider.user == null) {
      Future.microtask(() {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
      return const Center(child: CircularProgressIndicator());
    }

    // 2️⃣ If user has not joined any community -> send to join page
    if (authProvider.user?.communityId == null) {
      Future.microtask(() {
        Navigator.pushNamed(context, '/join-community');
      });
      return const Center(child: CircularProgressIndicator());
    }

    // 3️⃣ If user is waiting for approval
    if (authProvider.user?.isApproved == false) {
      return const PendingApprovalScreen();
    }

    // 4️⃣ Otherwise → Immediately show HistoryScreen (it will show skeleton while loading)
    return const HistoryScreen();
  }
}