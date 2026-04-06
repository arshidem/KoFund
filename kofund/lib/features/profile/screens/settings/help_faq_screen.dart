// lib/features/profile/screens/settings/help_faq_screen.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/features/profile/screens/settings/contact_support_screen.dart';
import 'package:kofund/core/utils/app_info.dart';


class HelpFAQScreen extends StatefulWidget {
  const HelpFAQScreen({super.key});

  @override
  State<HelpFAQScreen> createState() => _HelpFAQScreenSate();
}

class _HelpFAQScreenSate extends State<HelpFAQScreen> {

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

  @override
  Widget build(BuildContext context) {
    final List<FAQItem> faqItems = [
      FAQItem(
        question: 'How do I join a program?',
        answer: 'Go to the Programs tab, browse available programs, and tap "Join Program". You may need to pay a contribution fee if required.',
      ),
    
      FAQItem(
        question: 'Can I edit my profile information?',
        answer: 'Yes, go to Profile → Edit Profile. You can update your name, email, phone, and profile picture.',
      ),
      FAQItem(
        question: 'How do I invite others to my community?',
        answer: 'Admins can go to Dashboard and tap the share icon to generate an invite link or code to share with others.',
      ),
      FAQItem(
        question: 'What if I forget my password?',
        answer: 'Tap "Forgot Password" on the login screen. You\'ll receive an email with instructions to reset your password.',
      ),
      FAQItem(
        question: 'How do I report a problem?',
        answer: 'Use the "Contact Support" option below or email us directly at support@kofund.com',
      ),
    ];

    return GradientSheetScaffold(
      title: 'Help & FAQ',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                        Icons.help_outline,
                        size: 48,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'How can we help you?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Find answers to common questions or contact our support team.',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // FAQ Section Title
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap on any question to see the answer',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // FAQ List
              ...faqItems.map((faq) => _buildFAQItem(faq, context)),

              const SizedBox(height: 12),

              // Contact Support Button
        ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactSupportScreen(),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary(context),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    minimumSize: const Size(double.infinity, 50), // ← Add this line
  ),
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.support_agent),
      SizedBox(width: 8),
      Text('Contact Support Team'),
    ],
  ),
),

              const SizedBox(height: 20),

              // App Info
              Card(
                color: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAppInfoItem('App Version', appVersion),
                      _buildAppInfoItem('Last Updated', 'December 2025'),
                      _buildAppInfoItem('Developer', 'Kofund Team'),
                      _buildAppInfoItem('Support Hours', 'Mon-Fri, 9 AM - 6 PM'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(FAQItem faq, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          Icons.question_answer_outlined,
          color: AppColors.primary(context),
        ),
        title: Text(
          faq.question,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
        children: [
          Text(
            faq.answer,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      );
    }
  }


class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });
}

