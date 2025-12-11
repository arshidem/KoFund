import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../features/community/screens/join_community_screen.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => authProvider.refreshUserData(), // ✅ Use instance method
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.pending_actions,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            const Text(
              'Waiting for Approval',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your request to join ${authProvider.user?.communityCode ?? 'the community'} has been sent to the admin.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              'You will be able to access the community dashboard once approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => authProvider.refreshUserData(), // ✅ Use instance method
              child: const Text('Check Status'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Option to leave community and join another
                _showLeaveCommunityDialog(context, authProvider); // ✅ Pass instance
              },
              child: const Text('Join Different Community'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveCommunityDialog(BuildContext context, AppAuthProvider authProvider) { // ✅ Fixed parameter name
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Community?'),
        content: const Text('Do you want to leave this community and join a different one?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveCommunity(context, authProvider); // ✅ Pass instance
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveCommunity(BuildContext context, AppAuthProvider authProvider) async { // ✅ Fixed parameter name
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Use the proper provider method
      final success = await authProvider.removeUserFromCommunity(); // ✅ Use instance method

      // Close loading dialog
      Navigator.pop(context);

      if (success) {
        SnackbarHelper.showSuccess(context, 'Left community successfully');
        Navigator.pushReplacementNamed(context, '/join-community');
      } else {
        SnackbarHelper.showError(context, authProvider.error ?? 'Failed to leave community'); // ✅ Use instance
      }

    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      SnackbarHelper.showError(context, 'Failed to leave community: $e');
    }
  }
}