// lib/features/profile/screens/settings/terms_of_service_screen.dart
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Terms of Service Coming Soon!'),
            SizedBox(height: 16),
            Text('Our terms of service will be displayed here.'),
          ],
        ),
      ),
    );
  }
}