import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

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
                              'Help & Support',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We are here to help you manage your community funds smoothly.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            _buildSection(
                              context,
                              '1. Contact Information',
                              'If you run into any issues, have feature requests, or need technical help, please reach out:\n\n'
                              '• Support Email: support@kofund.web.app\n'
                              '• Administrative Office: admin@kofund-153ba.web.app',
                            ),

                            _buildSection(
                              context,
                              '2. Troubleshooting Guide',
                              'If the application is not loading or syncing correctly, please check the following:\n\n'
                              '• **Network Connection**: Ensure you are connected to active Wi-Fi or cellular networks. KoFund will fall back to local cached data if you are offline, but requires a connection to push edits.\n'
                              '• **Session Refresh**: If balances are not updating, try logging out and logging back in to re-authenticate your Firebase session.\n'
                              '• **Browser Compatibility**: We recommend using the latest versions of Google Chrome, Safari, or Mozilla Firefox.',
                            ),

                            _buildSection(
                              context,
                              '3. Response Expectations',
                              'Our support staff typically responds to all inquiries within 24 hours on weekdays (Monday to Friday). Weekend requests are handled on the following business day.',
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
