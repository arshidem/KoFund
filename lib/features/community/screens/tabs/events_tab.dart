// lib/features/community/screens/tabs/events_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/events/screens/all_events_screen.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // Get user info for admin check
    final authProvider = context.watch<AppAuthProvider>();
    final isAdmin = authProvider.user?.isAdmin == true || authProvider.user?.role == 'admin';
    // No auth checks needed - parent CommunityDashboard handles all auth verification
    return AllEventsScreen(isAdmin: isAdmin);
  }
}
