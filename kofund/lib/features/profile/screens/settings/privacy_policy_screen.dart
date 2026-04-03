// lib/features/profile/screens/settings/privacy_policy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kofund/core/utils/app_info.dart';
import 'package:flutter/foundation.dart' show debugPrint;


class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {

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

  Future<void> _launchPrivacyEmail(BuildContext context) async {
    final email = 'kofundapp@gmail.com';
    final subject = 'Privacy Policy Inquiry';
    final body = 'Hello KoFund Support,\n\nI have a question about the Privacy Policy:';
    
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
            content: Text('Privacy email copied to clipboard'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Privacy Policy',
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
                        Icons.privacy_tip_rounded,
                        size: 48,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Privacy Policy',
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
                          'Effective: December 2025',
                          style: TextStyle(
                            color: AppColors.primary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your privacy is important to us. This policy explains how we handle your data.',
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
                color: Colors.blue[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.blue[300]!,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: Colors.blue[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data Protection Notice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'We do NOT collect banking details, card information, or payment data. KoFund is a record-keeping tool only.',
                              style: TextStyle(
                                color: Colors.blue[800],
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

              // Privacy Policy Sections
              _buildPrivacySection(
                context,
                '1. Information We Collect',
                'We may collect the following types of data:\n\n'
                'a) Personal Information\n'
                '• Name, email address, or phone number (if provided during account creation)\n\n'
                'b) Group & Activity Data\n'
                '• Contributions\n'
                '• Expenses\n'
                '• Group activity history\n'
                '• Member participation records\n\n'
                'c) Technical Information\n'
                '• Device type\n'
                '• Operating system\n'
                '• App usage data\n'
                '• Crash and performance logs\n\n'
                'We do not collect banking details, card information, or payment data.',
              ),

              _buildPrivacySection(
                context,
                '2. How We Use Information',
                'We use collected data to:\n\n'
                '• Provide and operate core app features\n'
                '• Display group fund records and history\n'
                '• Improve app performance and reliability\n'
                '• Communicate important service updates',
              ),

              _buildPrivacySection(
                context,
                '3. Data Sharing',
                '• We do not sell, trade, or rent personal data\n'
                '• Data is visible only to members within the same group\n'
                '• We may use trusted third-party services (such as cloud hosting or analytics) strictly to operate the app',
              ),

              _buildPrivacySection(
                context,
                '4. Data Storage and Security',
                '• Data is stored using secure servers and standard protection measures\n'
                '• We take reasonable steps to safeguard data\n'
                '• No system is completely secure; use is at your own risk',
              ),

              _buildPrivacySection(
                context,
                '5. Data Retention',
                '• Group contribution and expense records may remain even if a user leaves or is removed\n'
                '• Account deletion may not erase shared group history\n'
                '• Data is retained only as long as necessary for app functionality',
              ),

              _buildPrivacySection(
                context,
                '6. User Rights',
                'Users may:\n\n'
                '• Access or update their account information\n'
                '• Request account deletion\n\n'
                'Requests may be limited where data is part of shared group records.',
              ),

              _buildPrivacySection(
                context,
                '7. Children\'s Privacy',
                'KoFund is not intended for children under the age of 13.\n'
                'We do not knowingly collect data from children.',
              ),

              _buildPrivacySection(
                context,
                '8. Changes to This Privacy Policy',
                'We may update this policy from time to time.\n'
                'Continued use of KoFund after updates means acceptance of the revised policy.',
              ),

              _buildPrivacySection(
                context,
                '9. Contact Information',
                'For questions or privacy concerns, contact:',
              ),

              const SizedBox(height: 12),

              // Contact Card
              Card(
                color: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => _launchPrivacyEmail(context),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.email,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(
                    'Privacy Support',
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

              // Your Data Rights Card
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
                            Icons.lock_person_rounded,
                            color: AppColors.primary(context),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Privacy Rights',
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
                                    'You have the right to:',
                                    style: TextStyle(
                                      color: AppColors.textPrimary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildPrivacyRightItem(
                              'Know what data we collect about you',
                              context,
                            ),
                            _buildPrivacyRightItem(
                              'Access and update your personal information',
                              context,
                            ),
                            _buildPrivacyRightItem(
                              'Request deletion of your account data',
                              context,
                            ),
                            _buildPrivacyRightItem(
                              'Understand how your data is shared',
                              context,
                            ),
                            _buildPrivacyRightItem(
                              'Contact us with privacy concerns',
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

              // Version & Company Info
              Center(
                child: Column(
                  children: [
                    Text(
                      'KoFund Privacy Policy',
                      style: TextStyle(
                        color: AppColors.textTertiary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $appVersion • Last updated: December 2025',
                      style: TextStyle(
                        color: AppColors.textTertiary(context),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© 2025 KoFund. All rights reserved.',
                      style: TextStyle(
                        color: AppColors.textTertiary(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection(BuildContext context, String title, String content) {
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

  Widget _buildPrivacyRightItem(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 14,
            color: AppColors.primary(context),
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

