import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class DataSafetyPage extends StatelessWidget {
  const DataSafetyPage({super.key});

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
                              'Data Safety',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'How we protect your community finances and individual privacy.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            _buildSection(
                              context,
                              '1. What Data is Collected',
                              'KoFund collects community name, admin logs, contribution ledgers, expense logs, user display names, email addresses, and phone numbers. We do NOT collect or store direct bank account passwords, credit card numbers, or automated banking transaction feeds.',
                            ),

                            _buildSection(
                              context,
                              '2. Why Data is Collected',
                              'Ledger data is collected purely to calculate and display real-time balances, track who has contributed to event sub-funds, and generate transparent audit reports for all members of the community.',
                            ),

                            _buildSection(
                              context,
                              '3. Firebase Security & Storage Rules',
                              'All data is encrypted in transit using SSL/TLS and encrypted at rest on Google Cloud Servers. We implement strict Firestore Security Rules to guarantee that only registered and approved members of a community can view that community\'s ledger, and only authorized administrators can log expenses or modify contribution records.',
                            ),

                            _buildSection(
                              context,
                              '4. User Controls & Data Deletion',
                              'You have full control over your profile. At any time, you can request manual removal, download a copy of your personal data, or delete your account permanently via settings, which instantly cleanses your data from active authentication directories.',
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
