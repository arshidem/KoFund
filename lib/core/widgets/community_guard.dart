// lib/core/widgets/community_guard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/app_auth_provider.dart';
import '../../routing/route_names.dart';
import 'package:go_router/go_router.dart';

/// Simple, low-cost guard for community-related screens
/// Uses cached data only - NO Firestore real-time listeners
class CommunityGuard extends StatelessWidget {
  final Widget child;
  
  const CommunityGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    
    // Quick check using cached data (NO network calls)
    if (authProvider.isLoading) {
      return _buildLoadingScreen('Loading user data...');
    }
    
    if (!authProvider.canAccessApp) {
      return _redirectTo(context, RouteNames.login, 'Please sign in');
    }
    
    if (authProvider.needsToJoinCommunity) {
      return _redirectTo(context, RouteNames.joinCommunity, 'Join a community first');
    }
    
    if (authProvider.isWaitingForApproval || 
        authProvider.user?.isApproved == false) {
      return _redirectTo(context, RouteNames.pendingApproval, 'Waiting for admin approval');
    }
    
    // All checks passed - user is authenticated and approved
    return child;
  }
  
  Widget _redirectTo(BuildContext context, String route, String message) {
    // Schedule navigation for next frname
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.go(route);
      }
    });
    
    return _buildLoadingScreen(message);
  }
  
  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}





