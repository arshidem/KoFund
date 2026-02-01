// lib/features/profile/screens/settings/terms_of_service_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kofund/core/utils/app_info.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  String appVersion = '1.0.0';
  String buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

Future<void> _loadAppInfo() async {
  debugPrint('Loading app info...');
  final version = await AppInfo.appVersion;
  final build = await AppInfo.buildNumber;
  debugPrint('Got version: $version, build: $build');
  
  if (mounted) {
    setState(() {
      appVersion = version;
      buildNumber = build;
    });
    debugPrint('State updated to version: $appVersion');
  }
}
  Future<void> _launchSupportEmail(BuildContext context) async {
    final email = 'kofundapp@gmail.com';
    final subject = 'Terms of Service Inquiry';
    final body = 'Hello KoFund Support,\n\nI have a question about the Terms of Service:';
    
    final nativeUrl = Uri.parse('mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    
    try {
      final result = await launchUrl(
        nativeUrl,
        mode: LaunchMode.externalApplication,
      );
      
      if (!result) {
        // Fallback to webmail
        final gmailUrl = Uri.parse(
          'https://mail.google.com/mail/?view=cm&fs=1&to=$email&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}'
        );
        await launchUrl(gmailUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Copy email to clipboard
      final text = 'To: $email\nSubject: $subject\n\n$body';
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support email copied to clipboard'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        toolbarHeight: 80,
        title: Text(
          'Terms of Service',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                color: AppColors.card(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        size: 48,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Terms of Service',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary(context).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Last updated: December 2025',
                          style: TextStyle(
                            color: AppColors.primary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'By accessing or using KoFund, you agree to these Terms of Service.',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Important Notice Card
              Card(
                color: Colors.amber[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.amber[300]!,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important Notice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[900],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'KoFund is a record-keeping tool only. We do NOT handle, store, or process real money. All financial transactions occur outside the app.',
                              style: TextStyle(
                                color: Colors.amber[800],
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Terms Sections (without icons)
              _buildTermSection(
                context,
                '1. Acceptance of Terms',
                'By accessing or using KoFund, you agree to these Terms of Service. If you do not agree, do not use the app.',
              ),

              _buildTermSection(
                context,
                '2. Purpose of KoFund',
                'KoFund is a record-keeping and transparency tool for groups and communities to track contributions and expenses for activities such as trips, tournaments, or programs.\n\n'
                'KoFund does not handle, store, transfer, or process real money or payments. All financial transactions occur outside the app.',
              ),

              _buildTermSection(
                context,
                '3. Accounts and Roles',
                '• KoFund groups may have different roles, including administrators and members.\n'
                '• Administrators are responsible for creating groups and adding, editing, or managing contribution and expense records.\n'
                '• Members may view group records but may not have permission to modify them.\n'
                '• You are responsible for maintaining the accuracy of any information you provide.',
              ),

              _buildTermSection(
                context,
                '4. Contributions and Expenses',
                '• All contribution and expense data is user-entered.\n'
                '• KoFund does not verify the accuracy, completeness, or validity of any records.\n'
                '• KoFund is not responsible for errors, omissions, or disputes related to group funds.\n'
                '• Any disagreements must be resolved between group members, not through KoFund.',
              ),

              _buildTermSection(
                context,
                '5. Data Retention and History',
                'For transparency and record-keeping:\n\n'
                '• Contribution and expense history may remain visible even if a member is removed or leaves a group.\n'
                '• Deleting an account may not remove historical records that are part of a group\'s shared activity.',
              ),

              _buildTermSection(
                context,
                '6. User Conduct',
                'You agree not to:\n'
                '• Enter false or misleading data\n'
                '• Misuse the app for illegal activities\n'
                '• Harass or abuse other users\n\n'
                'Violation of these rules may result in suspension or removal.',
              ),

              _buildTermSection(
                context,
                '7. Account Suspension and Termination',
                'KoFund may suspend or terminate accounts that misuse the app or violate these terms. We reserve the right to modify or discontinue features at any time.',
              ),

              _buildTermSection(
                context,
                '8. Limitation of Liability',
                'KoFund is provided "as is".\n\n'
                'We are not responsible for financial losses, disputes, or decisions made based on app data.\n\n'
                'Use of KoFund is at your own risk.',
              ),

              _buildTermSection(
                context,
                '9. Privacy',
                'How we collect and use personal data is explained in our Privacy Policy. Please review it separately.',
              ),

              _buildTermSection(
                context,
                '10. Changes to These Terms',
                'We may update these terms from time to time. Continued use of KoFund means you accept the updated terms.',
              ),

              _buildTermSection(
                context,
                '11. Contact',
                'For questions or support, contact us at:',
              ),

              const SizedBox(height: 12),

              // Contact Card
              Card(
                color: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => _launchSupportEmail(context),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.email,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(
                    'Email Support',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    'kofundapp@gmail.com',
                    style: TextStyle(
                      color: AppColors.primary(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Acceptance Card
  // Acceptance Card
Card(
  color: AppColors.surface(context),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.primary(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Your Acceptance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border(context),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline,
                      color: AppColors.primary(context),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By continuing to use KoFund, you acknowledge that:',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildAcceptanceItem(
                'You have read these Terms of Service',
                context,
              ),
              _buildAcceptanceItem(
                'KoFund is a record-keeping tool only',
                context,
              ),
              _buildAcceptanceItem(
                'We do not handle or process real money',
                context,
              ),
              _buildAcceptanceItem(
                'You use KoFund at your own risk',
                context,
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),

              const SizedBox(height: 24),

              // Version Info
              Center(
                child: Text(
                  'Version $appVersion • KoFund © 2025',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermSection(BuildContext context, String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.border(context),
                width: 1,
              ),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptanceItem(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


