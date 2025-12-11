// lib/features/profile/screens/settings/report_issue_screen.dart
import 'package:flutter/material.dart';

class ReportIssueScreen extends StatelessWidget {
  const ReportIssueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Issue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Report Issue Feature Coming Soon!'),
            SizedBox(height: 16),
            Text('You will be able to report issues here in the next update.'),
          ],
        ),
      ),
    );
  }
}