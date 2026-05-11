// lib/features/community/screens/tabs/dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/dashboard/screens/dashboard_screen.dart';

class DashboardTab extends StatelessWidget { // Changed to StatelessWidget
  final VoidCallback? onNavigateToMembers;
  
  const DashboardTab({super.key, this.onNavigateToMembers});

  @override
  Widget build(BuildContext context) {
    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return DashboardScreen(onNavigateToMembers: onNavigateToMembers);
  }
}





