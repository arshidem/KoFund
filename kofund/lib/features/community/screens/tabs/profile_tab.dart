// lib/features/community/screens/tabs/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/profile/screens/profile_screen.dart';

class ProfileTab extends StatelessWidget { // Changed to StatelessWidget
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return const ProfileScreen();
  }
}