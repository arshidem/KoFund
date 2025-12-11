// lib/features/community/screens/tabs/members_tab.dart
import 'package:flutter/material.dart';
import '../../../../features/members/screens/all_members_screen.dart';

class MembersTab extends StatelessWidget {
  const MembersTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Remove MultiProvider - use the existing providers from main app
    return const AllMembersScreen();
  }
}