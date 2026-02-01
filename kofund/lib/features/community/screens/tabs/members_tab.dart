// lib/features/community/screens/tabs/members_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/members/screens/all_members_screen.dart';

class MembersTab extends StatelessWidget { // Changed to StatelessWidget
  const MembersTab({super.key});

  @override
  Widget build(BuildContext context) {
    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return const AllMembersScreen();
  }
}
