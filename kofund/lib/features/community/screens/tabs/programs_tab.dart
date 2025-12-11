// lib/features/community/screens/tabs/programs_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:kofund/features/programs/screens/all_programs_screen.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../pending_approval_screen.dart';
import '../join_community_screen.dart';

class ProgramsTab extends StatefulWidget {
  const ProgramsTab({super.key});

  @override
  State<ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends State<ProgramsTab> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final authProvider = context.read<AppAuthProvider>();
    final programProvider = context.read<ProgramProvider>();
    
    if (authProvider.user?.communityId != null) {
      await programProvider.loadCommunityPrograms(authProvider.user!.communityId!);
      await programProvider.loadMyParticipations(
        authProvider.user!.uid, 
        authProvider.user!.communityId!
      );
    }
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // Check if current user is admin - FIXED VERSION
  bool _isUserAdmin(AppAuthProvider authProvider) {
    return authProvider.user?.isAdmin == true || 
           authProvider.user?.role == 'admin';
  }

  // Navigate to community join/create screen
  void _navigateToCommunityScreen(BuildContext context) {
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final programProvider = context.watch<ProgramProvider>(); // ✅ Watch program provider
    final isAdmin = _isUserAdmin(authProvider);
    
    // Check if user has a community - NAVIGATE to community screen
    if (authProvider.user?.communityId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToCommunityScreen(context);
      });
      
      return const LoadingIndicator(message: 'Redirecting to community...');
    }

    // Check if user is approved - navigate to pending approval screen
    if (authProvider.user?.isApproved == false) {
      return const PendingApprovalScreen();
    }

    // ✅ REMOVE this loading check - let AllProgramsScreen handle its own loading state
    // Return the AllProgramsScreen with admin permission
    return AllProgramsScreen(isAdmin: isAdmin);
  }
}