// lib/features/community/screens/tabs/history_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/history/screens/history_screen.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return const HistoryScreen();
  }
}
