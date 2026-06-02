import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = AppColors.primary(context);

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
                              'Delete Account',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Learn how to permanently erase your profile and records from KoFund.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Warning box
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Warning: Permanent Action',
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Deleting your account is permanent and irreversible. All personal details, community memberships, and individual contribution histories will be permanently wiped. Ledger entries created on behalf of the community may be preserved to prevent database corruption, but all identifying member records will be permanently decoupled.',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: Colors.red.withValues(alpha: 0.9),
                                            height: 1.5,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),

                            _buildSection(
                              context,
                              'Steps to Delete via Web App',
                              '1. Log into your account at https://kofund-153ba.web.app/login\n'
                              '2. Go to your Profile settings screen.\n'
                              '3. Click on the "Account Settings" or "Security" tab.\n'
                              '4. Click the "Delete Account" button.\n'
                              '5. Confirm your password and verify identity to initiate deletion.',
                            ),

                            _buildSection(
                              context,
                              'Delete via Support Email Request',
                              'If you cannot log into the web app, or if you prefer to have our administration handle the deletion manually:\n\n'
                              '• Email us at delete-account@kofund.web.app\n'
                              '• Subject line: "Account Deletion Request - [Your Name]"\n'
                              '• Please email us from the exact email address associated with your KoFund account to prove ownership.\n'
                              '• Requests are processed within 48 to 72 hours.',
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
