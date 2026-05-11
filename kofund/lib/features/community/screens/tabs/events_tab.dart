// lib/features/community/screens/tabs/events_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/events/screens/all_events_screen.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';

class eventsTab extends StatelessWidget { // Changed to StatelessWidget
  const eventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Get user info for admin check
    final _authProvider = context.watch<AppAuthProvider>();
    final isAdmin = _authProvider.user?.isAdmin == true || 
                    _authProvider.user?.role == 'admin';

    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return AllEventsScreen(isAdmin: isAdmin);
  }
}





