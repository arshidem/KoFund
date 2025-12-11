// lib/features/profile/screens/settings/privacy_policy_screen.dart
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Privacy Policy Coming Soon!'),
            SizedBox(height: 16),
            Text('Our privacy policy will be displayed here.'),
          ],
        ),
      ),
    );
  }
}