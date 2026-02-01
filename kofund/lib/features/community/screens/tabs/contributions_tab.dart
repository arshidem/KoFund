// lib/features/community/screens/tabs/contributions_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/contributions/screens/all_contribution_screen.dart';

class ContributionsTab extends StatelessWidget { // Changed to StatelessWidget
  const ContributionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return const AllContributionsScreen();
  }
}
