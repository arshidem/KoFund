import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      endDrawer: const WebsiteDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const WebsiteNavbar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Privacy Policy',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Last Updated: June 2026',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary(context),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            _buildSection(
                              context,
                              '1. Introduction',
                              'KoFund ("we", "our", or "us") values your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our web and mobile applications.',
                            ),
                            
                            _buildSection(
                              context,
                              '2. Data Collection',
                              'We collect personal details to provide and improve the KoFund experience. This includes:\n\n'
                              '• Name and Display Name\n'
                              '• Email Address (for accounts, login, security)\n'
                              '• Phone Number (used to identify member registry)\n'
                              '• Community affiliations and financial ledger transactions.',
                            ),

                            _buildSection(
                              context,
                              '3. Firebase Authentication & Cloud Services',
                              'We utilize Firebase Authentication to securely manage logins, account verification, and password resets. Your passwords are encrypted at rest and never visible to our administrators. All community records, balances, contributions, and metadata are stored securely on Google Cloud Firestore and protected by rigorous Security Rules.',
                            ),

                            _buildSection(
                              context,
                              '4. User Rights',
                              'You have the right to:\n\n'
                              '• Access the personal data we store about you.\n'
                              '• Request corrections to incorrect details.\n'
                              '• Revoke community access or request absolute account deletion at any time.',
                            ),

                            _buildSection(
                              context,
                              '5. Data Deletion Process',
                              'If you wish to terminate your account and wipe all stored telemetry data, you can navigate to the "Delete Account" option under your settings, or visit our dedicated Delete Account webpage. Initiating account deletion permanently removes your personal profile, credentials, and affiliations from our active identity servers.',
                            ),

                            _buildSection(
                              context,
                              '6. Contact Information',
                              'For any queries, concerns, or requests regarding this Privacy Policy, please contact our support team at support@kofund.web.app.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const WebsiteFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String heading, String body) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
