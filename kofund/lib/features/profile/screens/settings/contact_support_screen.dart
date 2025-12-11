// lib/features/profile/screens/settings/contact_support_screen.dart
import 'package:flutter/material.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Contact Support Coming Soon!'),
            SizedBox(height: 16),
            Text('Support contact information will be added here.'),
          ],
        ),
      ),
    );
  }
}