import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
                              'About KoFund',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A transparent, dedicated platform for joint committee fund management.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            _buildSection(
                              context,
                              'Our Mission',
                              'KoFund was born out of a simple observation: communities, committees, clubs, and family groups struggle to manage joint funds cleanly. Traditional methods like WhatsApp chats, spreadsheet links, and paper notebooks lead to miscommunication, forgotten payments, and trust issues.\n\n'
                              'Our mission is to eliminate WhatsApp financial confusion by providing a single source of truth that is accessible, transparent, secure, and user-friendly.',
                            ),

                            _buildSection(
                              context,
                              'Product Overview',
                              'KoFund is a dedicated software-as-a-service application that allows community administrators to invite members, set up contribution targets, log event expenses, and share live balance sheets. Members can view records, export historical reports, and receive reminders without waiting for manual balance updates in chat groups.',
                            ),

                            _buildSection(
                              context,
                              'Key Benefits',
                              '• **Absolute Transparency**: Every single payout or collection is listed on the live ledger. Trust is maintained across the entire organization.\n'
                              '• **Saves Time**: Admins do not need to constantly reply to "what is the balance?" or "did my payment arrive?" messages.\n'
                              '• **Sub-Fund Segmentation**: Separate balances for specific events (e.g., charity drives, building renovation, trips) ensure money is never mixed up.',
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
