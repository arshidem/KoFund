// lib/features/community/screens/tabs/programs_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:kofund/features/programs/screens/all_programs_screen.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';

class ProgramsTab extends StatelessWidget { // Changed to StatelessWidget
  const ProgramsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Get user info for admin check
    final authProvider = context.watch<AppAuthProvider>();
    final isAdmin = authProvider.user?.isAdmin == true || 
                    authProvider.user?.role == 'admin';

    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return AllProgramsScreen(isAdmin: isAdmin);
  }
}