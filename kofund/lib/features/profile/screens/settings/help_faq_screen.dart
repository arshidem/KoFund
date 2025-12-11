// lib/features/profile/screens/settings/help_faq_screen.dart
import 'package:flutter/material.dart';

class HelpFAQScreen extends StatelessWidget {
  const HelpFAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Help & FAQ Coming Soon!'),
            SizedBox(height: 16),
            Text('Frequently asked questions will be added here.'),
          ],
        ),
      ),
    );
  }
}