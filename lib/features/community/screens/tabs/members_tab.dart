// lib/features/community/screens/tabs/members_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/members/screens/all_members_screen.dart';

class MembersTab extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback? onBackToDashboard;
  
  const MembersTab({
    super.key, 
    this.showBackButton = false,
    this.onBackToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return AllMembersScreen(
      forceBackButton: showBackButton,
      onBack: onBackToDashboard,
    );
  }
}





