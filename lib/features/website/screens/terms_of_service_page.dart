import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

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
                              'Terms of Service',
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
                              '1. Agreement to Terms',
                              'By accessing and using KoFund, you agree to comply with and be bound by these Terms of Service. If you do not agree, please do not use the application.',
                            ),

                            _buildSection(
                              context,
                              '2. User Responsibilities',
                              'Users are responsible for maintaining the confidentiality of their credentials and active sessions. Any financial data, member lists, and community ledgers uploaded must be accurate, true, and comply with local financial regulations.',
                            ),

                            _buildSection(
                              context,
                              '3. Acceptable Use',
                              'You agree not to use KoFund for any illegal activities, money laundering, fraud, or misrepresenting community assets. Violation of this clause will lead to instant account termination.',
                            ),

                            _buildSection(
                              context,
                              '4. Account Ownership',
                              'You own the data and content you upload to KoFund. However, you grant us a license to host, display, and process this data as necessary to provide service functionality. We claim no ownership over community funds.',
                            ),

                            _buildSection(
                              context,
                              '5. Service Availability & Modification',
                              'While we strive for 99.9% uptime, KoFund is provided "as is" and "as available". We reserve the right to temporarily modify, suspend, or discontinue the service with or without notice for system maintenance.',
                            ),

                            _buildSection(
                              context,
                              '6. Limitation of Liability',
                              'In no event shall KoFund or its creators be liable for any direct, indirect, incidental, or consequential damages resulting from the use of, or inability to use, the platform or any errors in financial tracking.',
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
