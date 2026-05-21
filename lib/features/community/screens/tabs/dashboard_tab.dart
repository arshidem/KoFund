// lib/features/community/screens/tabs/dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/dashboard/screens/dashboard_screen.dart';

class DashboardTab extends StatelessWidget {
  final VoidCallback? onNavigateToMembers;
  final VoidCallback? onNavigateToEvents;
  
  const DashboardTab({super.key, this.onNavigateToMembers, this.onNavigateToEvents});

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(
      onNavigateToMembers: onNavigateToMembers,
      onNavigateToEvents: onNavigateToEvents,
    );
  }
}





