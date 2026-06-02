import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _launchWebApp(BuildContext context) {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      endDrawer: const WebsiteDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const WebsiteNavbar(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    _HeroSection(
                      onOpenApp: () => _launchWebApp(context),
                      onLearnMore: () {
                        // Scroll to features section
                        scrollController.animateTo(
                          650,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    const _FeaturesSection(),
                    const _WhyKoFundSection(),
                    const _UseCasesSection(),
                    const _FAQSection(),
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
}

class _HeroSection extends StatelessWidget {
  final VoidCallback onOpenApp;
  final VoidCallback onLearnMore;

  const _HeroSection({
    required this.onOpenApp,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = AppColors.primary(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: isMobile ? 64 : 120,
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Simplify Community Finances',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Main Title
            Text(
              'Manage Community Funds Without WhatsApp Confusion',
              textAlign: TextAlign.center,
              style: (isMobile ? textTheme.headlineMedium : textTheme.displayMedium)
                  ?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary(context),
                height: 1.15,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),

            // Subtitle
            Text(
              'KoFund helps communities, committees, clubs, events, and organizations manage contributions, expenses, members, and balances in one place.',
              textAlign: TextAlign.center,
              style: (isMobile ? textTheme.bodyLarge : textTheme.titleMedium)?.copyWith(
                color: AppColors.textSecondary(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            // CTA Buttons
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onOpenApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Open Web App'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: onLearnMore,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    side: BorderSide(
                      color: AppColors.border(context),
                      width: 2,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(
                    'Learn More',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;

    final isTablet = ResponsiveLayout.isTablet(context);

    final features = [
      _FeatureItem(
        icon: Icons.track_changes_rounded,
        title: 'Contribution Tracking',
        description: 'Easily track incoming community contributions, schedules, and individual member payments.',
      ),
      _FeatureItem(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Expense Management',
        description: 'Log and organize all committee payouts, event expenses, and bills transparently.',
      ),
      _FeatureItem(
        icon: Icons.people_alt_rounded,
        title: 'Member Management',
        description: 'Keep track of all members, roles, approvals, and contact information seamlessly.',
      ),
      _FeatureItem(
        icon: Icons.event_available_rounded,
        title: 'Event & Program Funds',
        description: 'Create unique sub-funds and accounts specifically designated for festivals, trips, or programs.',
      ),
      _FeatureItem(
        icon: Icons.query_stats_rounded,
        title: 'Real-time Balances',
        description: 'Members instantly view live fund balances, total collected, and remaining budgets.',
      ),
      _FeatureItem(
        icon: Icons.cloud_done_rounded,
        title: 'Secure Cloud Storage',
        description: 'Your community records are safely hosted and secured on industry-standard cloud storage.',
      ),
      _FeatureItem(
        icon: Icons.history_edu_rounded,
        title: 'Reports & History',
        description: 'Export rich transaction histories, audit reports, and payment logs anytime.',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 80,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            Text(
              'Everything You Need to Run Smoothly',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 3),
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: isTablet ? 1.4 : 1.3,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final item = features[index];
                return _FeatureCard(item: item);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _FeatureCard extends StatefulWidget {
  final _FeatureItem item;

  const _FeatureCard({required this.item});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: _isHovered ? (Matrix4.identity()..translate(0, -6, 0)) : Matrix4.identity(),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? primaryColor : AppColors.border(context),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? (isDark ? 0.3 : 0.05) : 0.0),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.icon,
              color: primaryColor,
              size: 32,
            ),
            const SizedBox(height: 16),
            Text(
              widget.item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.description,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyKoFundSection extends StatelessWidget {
  const _WhyKoFundSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 80,
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCard.withValues(alpha: 0.3)
          : AppColors.lightBackground.withValues(alpha: 0.5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Text(
              'Why Choose KoFund?',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Traditional notes and chat apps fall short when it comes to accountability and organization.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  border: Border.all(
                    color: AppColors.border(context),
                  ),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.2),
                    3: FlexColumnWidth(1.2),
                  },
                  border: TableBorder.symmetric(
                    inside: BorderSide(
                      color: AppColors.border(context),
                    ),
                  ),
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                      ),
                      children: [
                        _buildTableCell('Feature', isHeader: true),
                        _buildTableCell('WhatsApp', isHeader: true, alignCenter: true),
                        _buildTableCell('Notes App', isHeader: true, alignCenter: true),
                        _buildTableCell('KoFund', isHeader: true, alignCenter: true),
                      ],
                    ),
                    // Rows
                    _buildComparisonRow('Track Contributions', '❌', '⚠️', '✅'),
                    _buildComparisonRow('Track Expenses', '❌', '⚠️', '✅'),
                    _buildComparisonRow('Member Management', '❌', '❌', '✅'),
                    _buildComparisonRow('Reports & History', '❌', '❌', '✅'),
                    _buildComparisonRow('Transparency', '❌', '❌', '✅'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildComparisonRow(String feature, String whatsapp, String notes, String kofund) {
    return TableRow(
      children: [
        _buildTableCell(feature),
        _buildTableCell(whatsapp, alignCenter: true),
        _buildTableCell(notes, alignCenter: true),
        _buildTableCell(kofund, alignCenter: true),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool alignCenter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Text(
        text,
        textAlign: alignCenter ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          color: isHeader ? null : (text == '✅' ? AppColors.lightSuccess : null),
          fontSize: isHeader ? 14 : 14,
        ),
      ),
    );
  }
}

class _UseCasesSection extends StatelessWidget {
  const _UseCasesSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;

    final useCases = [
      _UseCaseItem(icon: Icons.mosque_rounded, title: 'Mosque Committees'),
      _UseCaseItem(icon: Icons.group_rounded, title: 'Community Groups'),
      _UseCaseItem(icon: Icons.celebration_rounded, title: 'Event Organizers'),
      _UseCaseItem(icon: Icons.family_restroom_rounded, title: 'Family Funds'),
      _UseCaseItem(icon: Icons.volunteer_activism_rounded, title: 'Charity Collections'),
      _UseCaseItem(icon: Icons.school_rounded, title: 'Student Organizations'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 80,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Text(
              'Perfect For Every Committee & Group',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'No matter your organization size, KoFund fits right in.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: useCases.map((useCase) {
                return _UseCaseCard(useCase: useCase);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _UseCaseItem {
  final IconData icon;
  final String title;

  _UseCaseItem({required this.icon, required this.title});
}

class _UseCaseCard extends StatelessWidget {
  final _UseCaseItem useCase;

  const _UseCaseCard({required this.useCase});

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary(context);

    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(useCase.icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              useCase.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQSection extends StatelessWidget {
  const _FAQSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;

    final faqs = [
      _FAQItem(
        question: 'Who can use KoFund?',
        answer: 'KoFund is designed for anyone managing money jointly. This includes mosque committees, local event organizers, student organizations, charity collections, family savings pools, and housing societies.',
      ),
      _FAQItem(
        question: 'Is my data secure?',
        answer: 'Absolutely. We use Firebase Authentication to secure member logins and cloud security rules to ensure only approved committee members can edit or access community records.',
      ),
      _FAQItem(
        question: 'How do members track records?',
        answer: 'Members can log in to the web app to view transactions, contribution progress, and expenses in real-time. They can also view generated PDF reports.',
      ),
      _FAQItem(
        question: 'Does it support offline access?',
        answer: 'Yes! KoFund supports basic local caching so users can view data offline when an internet connection is unstable.',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 80,
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCard.withValues(alpha: 0.2)
          : AppColors.lightBackground.withValues(alpha: 0.3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Text(
              'Frequently Asked Questions',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: faqs.length,
              itemBuilder: (context, index) {
                final faq = faqs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ExpansionTile(
                      backgroundColor: AppColors.card(context),
                      collapsedBackgroundColor: AppColors.card(context),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(
                        faq.question,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                          child: Text(
                            faq.answer,
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQItem {
  final String question;
  final String answer;

  _FAQItem({required this.question, required this.answer});
}
