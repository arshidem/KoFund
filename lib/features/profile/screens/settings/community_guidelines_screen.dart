// lib/features/profile/screens/settings/community_guidelines_screen.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'package:kofund/core/utils/app_info.dart';


class CommunityGuidelinesScreen extends StatefulWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  State<CommunityGuidelinesScreen> createState() => CommunityGuidelinesScreenState();
}

class CommunityGuidelinesScreenState extends State<CommunityGuidelinesScreen> {


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
    return GradientSheetScaffold(
      title: 'Community Guidelines',
      body: SingleChildScrollView(
        child: Padding(
          padding: AppStyles.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                color: AppColors.card(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_work_rounded,
                        size: 48,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Community Guidelines',
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
                          'Last updated: December 2026',
                          style: TextStyle(
                            color: AppColors.primary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Promoting transparency, trust, and cooperation within groups',
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

              // Mission Card
              Card(
                color: Colors.green[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: Colors.green[300]!,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: Colors.green[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Our Mission',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'KoFund is built to promote transparency, trust, and cooperation within groups.',
                              style: TextStyle(
                                color: Colors.green[800],
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

              // Guidelines Sections with Icons
              _buildGuidelineSection(
                context,
                Icons.check_circle,
                Colors.blue,
                '1. Be Honest and Accurate',
                [
                  'Enter contributions and expenses truthfully',
                  'Do not submit false, misleading, or manipulated records',
                  'Verify information before sharing it with your group',
                ],
              ),

              _buildGuidelineSection(
                context,
                Icons.people_alt,
                Colors.purple,
                '2. Respect Other Members',
                [
                  'Treat all members with respect',
                  'No harassment, threats, or abusive language',
                  'No personal attacks or intimidation',
                ],
              ),

              _buildGuidelineSection(
                context,
                Icons.description,
                Colors.orange,
                '3. Use KoFund for Its Intended Purpose',
                [
                  'KoFund is for group fund tracking and transparency only',
                  'Do not use the app for scams, fraud, or illegal activities',
                  'Do not misuse group data for personal or commercial gain',
                ],
              ),

              _buildGuidelineSection(
                context,
                Icons.groups,
                Colors.teal,
                '4. Group Responsibility',
                [
                  'Group administrators are responsible for managing entries and members',
                  'Members should raise concerns within the group respectfully',
                  'KoFund does not mediate financial or personal disputes',
                ],
              ),

              _buildGuidelineSection(
                context,
                Icons.security,
                Colors.indigo,
                '5. Data and Privacy Respect',
                [
                  'Do not share screenshots or group data without permission',
                  'Respect the privacy of other members',
                  'Use shared information responsibly',
                ],
              ),

              _buildGuidelineSection(
                context,
                Icons.person_off,
                Colors.red,
                '6. No Impersonation or Misrepresentation',
                [
                  'Do not impersonate others',
                  'Do not create fake accounts or groups',
                  'Do not misrepresent contributions or expenses',
                ],
              ),

              _buildGuidelineSection(
                context,
                Icons.gavel,
                Colors.amber[700]!,
                '7. Enforcement',
                [
                  'Violations of these guidelines may result in:',
                  '• Warnings',
                  '• Temporary suspension',
                  '• Permanent account removal',
                  'Enforcement decisions are at KoFund\'s discretion.',
                ],
              ),

              _buildGuidelineSection(
                context,
                Icons.report_problem,
                Colors.deepOrange,
                '8. Reporting Issues',
                [
                  'Users are encouraged to report misuse or violations',
                  'Report through available support channels',
                  'Contact: kofundapp@gmail.com',
                ],
              ),

              const SizedBox(height: 32),

              // Agreement Card
              Card(
                color: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.handshake_rounded,
                            color: AppColors.primary(context),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Our Community Agreement',
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
                                    Icons.emoji_people_rounded,
                                    color: AppColors.primary(context),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'By using KoFund, you agree to:',
                                    style: TextStyle(
                                      color: AppColors.textPrimary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildAgreementItem(
                              'Follow these community guidelines',
                              context,
                            ),
                            _buildAgreementItem(
                              'Use KoFund responsibly and ethically',
                              context,
                            ),
                            _buildAgreementItem(
                              'Respect other group members',
                              context,
                            ),
                            _buildAgreementItem(
                              'Report any violations you encounter',
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

              // Links to other policies
              Card(
                color: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Related Policies',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPolicyLink(
                        context,
                        'Terms of Service',
                        Icons.gavel_rounded,
                        () {
                          // Navigate to Terms of Service screen
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TermsOfServiceScreen()));
                        },
                      ),
                      _buildPolicyLink(
                        context,
                        'Privacy Policy',
                        Icons.privacy_tip_rounded,
                        () {
                          // Navigate to Privacy Policy screen
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()));
                        },
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
                      'KoFund Community Guidelines',
                      style: TextStyle(
                        color: AppColors.textTertiary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $appVersion • Building better communities together',
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

  Widget _buildGuidelineSection(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    List<String> points,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Card(
        color: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: points.map((point) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point,
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementItem(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.thumb_up_alt_rounded,
            size: 14,
            color: Colors.green[600],
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

  Widget _buildPolicyLink(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border(context),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.primary(context),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






