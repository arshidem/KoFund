import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/website_navbar.dart';
import '../widgets/website_footer.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _launchWebApp(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      context.go('/splash');
    } else {
      context.go('/login');
    }
  }

  Future<void> _launchDownloadUrl() async {
    final url = Uri.parse('https://drive.google.com/file/d/1jQEGYyfAZjnt9L8PPqYpANaizGaq0gq0/view?usp=sharing');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    _HeroSection(
                      onOpenApp: () => _launchWebApp(context),
                      onDownloadApp: _launchDownloadUrl,
                    ),
                    const _FeaturesSection(),
                    const _RoleShowcase(),
                    const _WhyKoFundSection(),
                    const _AdminPainSection(),
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
  final VoidCallback onDownloadApp;

  const _HeroSection({
    required this.onOpenApp,
    required this.onDownloadApp,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = AppColors.primary(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    final isLoggedIn = authProvider.user != null;

    Widget buildContent() {
      return Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
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
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
            style: (isMobile ? textTheme.bodyLarge : textTheme.titleMedium)?.copyWith(
              color: AppColors.textSecondary(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // CTA Buttons
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 240,
                child: ElevatedButton(
                  onPressed: onOpenApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLoggedIn ? 'Go to Dashboard' : 'Open Web App'),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),

              SizedBox(
                width: isMobile ? double.infinity : 240,
                child: ElevatedButton(
                  onPressed: onDownloadApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    elevation: 0,
                    side: BorderSide(color: primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Download Android App'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: isMobile ? 40 : 64,
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  buildContent(),
                  const SizedBox(height: 32),
                  const _QrCodeWidget(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: buildContent()),
                  const SizedBox(width: 64),
                  const _QrCodeWidget(),
                ],
              ),
      ),
    );
  }
}

class _QrCodeWidget extends StatelessWidget {
  const _QrCodeWidget();

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary(context);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border(context),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _QrCodePainter(color: primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan to Download APK',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Direct Android Install',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCodePainter extends CustomPainter {
  final Color color;

  _QrCodePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double cellSize = size.width / 37;

    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, cellSize * 7, cellSize * 7), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + cellSize, y + cellSize, cellSize * 5, cellSize * 5),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + cellSize * 2, y + cellSize * 2, cellSize * 3, cellSize * 3),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(cellSize * 30, 0);
    drawFinder(0, cellSize * 30);

    final randomData = [
      [10, 0], [12, 0], [13, 0], [14, 0], [15, 0], [18, 0], [19, 0], [20, 0], [21, 0], [22, 0], [23, 0], [26, 0], [8, 1], [10, 1], [13, 1], [14, 1], [15, 1], [16, 1], [20, 1], [21, 1], [24, 1], [27, 1], [28, 1], [12, 2], [13, 2], [15, 2], [21, 2], [22, 2], [24, 2], [26, 2], [28, 2], [8, 3], [9, 3], [10, 3], [12, 3], [14, 3], [15, 3], [17, 3], [19, 3], [21, 3], [22, 3], [25, 3], [26, 3], [9, 4], [15, 4], [16, 4], [19, 4], [20, 4], [22, 4], [25, 4], [8, 5], [9, 5], [11, 5], [12, 5], [17, 5], [21, 5], [24, 5], [25, 5], [27, 5], [8, 6], [10, 6], [12, 6], [14, 6], [16, 6], [18, 6], [20, 6], [22, 6], [24, 6], [26, 6], [28, 6], [9, 7], [10, 7], [11, 7], [14, 7], [16, 7], [19, 7], [20, 7], [21, 7], [22, 7], [24, 7], [27, 7], [28, 7], [0, 8], [1, 8], [2, 8], [3, 8], [4, 8], [6, 8], [7, 8], [8, 8], [9, 8], [11, 8], [16, 8], [17, 8], [18, 8], [20, 8], [22, 8], [26, 8], [27, 8], [29, 8], [31, 8], [33, 8], [35, 8], [0, 9], [1, 9], [2, 9], [3, 9], [4, 9], [8, 9], [10, 9], [12, 9], [13, 9], [14, 9], [15, 9], [17, 9], [19, 9], [20, 9], [21, 9], [22, 9], [26, 9], [28, 9], [31, 9], [33, 9], [34, 9], [35, 9], [1, 10], [3, 10], [6, 10], [7, 10], [8, 10], [13, 10], [14, 10], [15, 10], [16, 10], [17, 10], [20, 10], [21, 10], [24, 10], [27, 10], [28, 10], [29, 10], [31, 10], [32, 10], [33, 10], [34, 10], [36, 10], [1, 11], [3, 11], [7, 11], [12, 11], [13, 11], [15, 11], [19, 11], [20, 11], [21, 11], [24, 11], [26, 11], [28, 11], [30, 11], [31, 11], [33, 11], [35, 11], [0, 12], [6, 12], [8, 12], [10, 12], [12, 12], [14, 12], [15, 12], [17, 12], [19, 12], [21, 12], [22, 12], [23, 12], [26, 12], [29, 12], [30, 12], [32, 12], [33, 12], [34, 12], [36, 12], [1, 13], [2, 13], [5, 13], [7, 13], [9, 13], [15, 13], [16, 13], [19, 13], [21, 13], [23, 13], [24, 13], [31, 13], [34, 13], [35, 13], [0, 14], [6, 14], [9, 14], [10, 14], [11, 14], [12, 14], [21, 14], [24, 14], [26, 14], [27, 14], [28, 14], [29, 14], [30, 14], [31, 14], [32, 14], [34, 14], [35, 14], [36, 14], [1, 15], [2, 15], [8, 15], [9, 15], [10, 15], [11, 15], [14, 15], [16, 15], [21, 15], [22, 15], [26, 15], [27, 15], [28, 15], [29, 15], [30, 15], [31, 15], [32, 15], [33, 15], [36, 15], [0, 16], [1, 16], [2, 16], [3, 16], [5, 16], [6, 16], [11, 16], [17, 16], [20, 16], [21, 16], [22, 16], [23, 16], [24, 16], [26, 16], [27, 16], [30, 16], [32, 16], [33, 16], [34, 16], [36, 16], [1, 17], [2, 17], [3, 17], [5, 17], [10, 17], [12, 17], [13, 17], [14, 17], [15, 17], [19, 17], [28, 17], [31, 17], [34, 17], [35, 17], [0, 18], [1, 18], [5, 18], [6, 18], [7, 18], [8, 18], [9, 18], [10, 18], [13, 18], [14, 18], [15, 18], [16, 18], [17, 18], [18, 18], [20, 18], [22, 18], [25, 18], [26, 18], [27, 18], [29, 18], [31, 18], [32, 18], [34, 18], [35, 18], [36, 18], [2, 19], [5, 19], [9, 19], [10, 19], [12, 19], [13, 19], [16, 19], [21, 19], [24, 19], [26, 19], [27, 19], [28, 19], [31, 19], [32, 19], [36, 19], [1, 20], [4, 20], [5, 20], [6, 20], [7, 20], [8, 20], [12, 20], [14, 20], [15, 20], [17, 20], [20, 20], [22, 20], [23, 20], [26, 20], [29, 20], [30, 20], [32, 20], [33, 20], [34, 20], [35, 20], [36, 20], [2, 21], [3, 21], [4, 21], [10, 21], [16, 21], [19, 21], [20, 21], [21, 21], [23, 21], [24, 21], [25, 21], [26, 21], [28, 21], [31, 21], [35, 21], [2, 22], [6, 22], [7, 22], [9, 22], [11, 22], [12, 22], [15, 22], [18, 22], [20, 22], [21, 22], [24, 22], [27, 22], [28, 22], [30, 22], [31, 22], [32, 22], [33, 22], [35, 22], [36, 22], [1, 23], [2, 23], [3, 23], [10, 23], [11, 23], [14, 23], [16, 23], [18, 23], [19, 23], [20, 23], [21, 23], [22, 23], [26, 23], [27, 23], [29, 23], [31, 23], [36, 23], [1, 24], [2, 24], [3, 24], [6, 24], [8, 24], [11, 24], [17, 24], [18, 24], [22, 24], [25, 24], [26, 24], [29, 24], [30, 24], [32, 24], [34, 24], [35, 24], [36, 24], [0, 25], [1, 25], [2, 25], [3, 25], [5, 25], [8, 25], [9, 25], [12, 25], [13, 25], [14, 25], [16, 25], [17, 25], [19, 25], [20, 25], [23, 25], [25, 25], [26, 25], [28, 25], [31, 25], [33, 25], [35, 25], [0, 26], [6, 26], [7, 26], [9, 26], [10, 26], [13, 26], [14, 26], [15, 26], [16, 26], [21, 26], [24, 26], [27, 26], [29, 26], [32, 26], [33, 26], [34, 26], [35, 26], [36, 26], [0, 27], [5, 27], [8, 27], [9, 27], [10, 27], [12, 27], [13, 27], [15, 27], [21, 27], [22, 27], [23, 27], [26, 27], [28, 27], [29, 27], [31, 27], [32, 27], [36, 27], [0, 28], [2, 28], [3, 28], [4, 28], [5, 28], [6, 28], [7, 28], [9, 28], [12, 28], [14, 28], [17, 28], [20, 28], [22, 28], [23, 28], [24, 28], [25, 28], [26, 28], [27, 28], [28, 28], [29, 28], [30, 28], [31, 28], [32, 28], [33, 28], [34, 28], [8, 29], [9, 29], [10, 29], [16, 29], [19, 29], [22, 29], [23, 29], [27, 29], [28, 29], [32, 29], [33, 29], [34, 29], [8, 30], [9, 30], [11, 30], [12, 30], [15, 30], [17, 30], [18, 30], [20, 30], [24, 30], [25, 30], [26, 30], [28, 30], [30, 30], [32, 30], [35, 30], [36, 30], [9, 31], [11, 31], [14, 31], [21, 31], [23, 31], [24, 31], [28, 31], [32, 31], [8, 32], [9, 32], [11, 32], [15, 32], [16, 32], [17, 32], [20, 32], [21, 32], [22, 32], [23, 32], [24, 32], [26, 32], [27, 32], [28, 32], [29, 32], [30, 32], [31, 32], [32, 32], [34, 32], [36, 32], [8, 33], [9, 33], [12, 33], [13, 33], [14, 33], [16, 33], [17, 33], [18, 33], [19, 33], [20, 33], [21, 33], [23, 33], [28, 33], [29, 33], [30, 33], [32, 33], [35, 33], [36, 33], [8, 34], [13, 34], [14, 34], [15, 34], [16, 34], [18, 34], [20, 34], [22, 34], [24, 34], [28, 34], [33, 34], [34, 34], [35, 34], [36, 34], [8, 35], [10, 35], [12, 35], [13, 35], [15, 35], [18, 35], [21, 35], [22, 35], [23, 35], [24, 35], [26, 35], [27, 35], [28, 35], [29, 35], [31, 35], [36, 35], [8, 36], [10, 36], [12, 36], [14, 36], [15, 36], [17, 36], [22, 36], [23, 36], [26, 36], [27, 36], [29, 36], [30, 36], [31, 36], [33, 36], [34, 36], [35, 36], [36, 36]
    ];

    for (final point in randomData) {
      canvas.drawRect(
        Rect.fromLTWH(point[0] * cellSize, point[1] * cellSize, cellSize, cellSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        title: 'Monthly & Event Contributions',
        description: 'Easily track recurring monthly fees for clubs, college groups, and societies, alongside one-off event targets.',
      ),
      _FeatureItem(
        icon: Icons.share_rounded,
        title: 'Public Sharing Links',
        description: 'Share a secure public link so all members can instantly view collection progress, expenses, and paid/unpaid lists.',
      ),
      _FeatureItem(
        icon: Icons.receipt_long_rounded,
        title: 'Instant Digital Receipts',
        description: 'Allow members to view and download their digital receipt once the admin marks their contribution as paid.',
      ),
      _FeatureItem(
        icon: Icons.picture_as_pdf_rounded,
        title: 'PDF & Image Summaries',
        description: 'Compile and generate clean event summaries in PDF or image format to easily share on messaging groups.',
      ),
      _FeatureItem(
        icon: Icons.notifications_active_rounded,
        title: 'Smart Push Reminders',
        description: 'Set custom reminders and send push notifications directly to members who have outstanding dues.',
      ),
      _FeatureItem(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Live Net Balances',
        description: 'Track the exact remaining budget and current net balances with automated expense deductions.',
      ),
      _FeatureItem(
        icon: Icons.people_alt_rounded,
        title: 'Member Management',
        description: 'Manage community members, approve join requests, and assign custom roles transparently.',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 48,
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
            Builder(
              builder: (context) {
                if (isMobile) {
                  return Column(
                    children: features.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _FeatureCard(item: item),
                    )).toList(),
                  );
                }
                
                final columnsCount = isTablet ? 2 : 3;
                final rows = <List<_FeatureItem>>[];
                for (var i = 0; i < features.length; i += columnsCount) {
                  final end = (i + columnsCount < features.length) ? i + columnsCount : features.length;
                  rows.add(features.sublist(i, end));
                }
                
                return Column(
                  children: rows.map((rowItems) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rowItems.map((item) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: _FeatureCard(item: item),
                              ),
                            );
                          }).toList() + List.generate(
                            columnsCount - rowItems.length,
                            (index) => const Expanded(child: SizedBox()),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }
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
        transform: _isHovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
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

    Widget buildTableContent() {
      return Table(
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
          _buildComparisonRow('Track Contributions', Icons.close_rounded, Colors.red, Icons.warning_amber_rounded, Colors.orange, Icons.check_circle_rounded, Colors.green),
          _buildComparisonRow('Track Expenses', Icons.close_rounded, Colors.red, Icons.warning_amber_rounded, Colors.orange, Icons.check_circle_rounded, Colors.green),
          _buildComparisonRow('Member Management', Icons.close_rounded, Colors.red, Icons.close_rounded, Colors.red, Icons.check_circle_rounded, Colors.green),
          _buildComparisonRow('Reports & History', Icons.close_rounded, Colors.red, Icons.close_rounded, Colors.red, Icons.check_circle_rounded, Colors.green),
          _buildComparisonRow('Transparency', Icons.close_rounded, Colors.red, Icons.close_rounded, Colors.red, Icons.check_circle_rounded, Colors.green),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 48,
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
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_left_alt_rounded,
                      size: 14,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Swipe horizontally to view full comparison',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  border: Border.all(
                    color: AppColors.border(context),
                  ),
                ),
                child: isMobile
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 560,
                          child: buildTableContent(),
                        ),
                      )
                    : buildTableContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildComparisonRow(String feature, IconData whatsappIcon, Color whatsappColor, IconData notesIcon, Color notesColor, IconData kofundIcon, Color kofundColor) {
    return TableRow(
      children: [
        _buildTableCell(feature),
        _buildIconTableCell(whatsappIcon, whatsappColor),
        _buildIconTableCell(notesIcon, notesColor),
        _buildIconTableCell(kofundIcon, kofundColor),
      ],
    );
  }

  Widget _buildIconTableCell(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(child: Icon(icon, color: color, size: 20)),
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
          fontSize: 14,
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
        vertical: 48,
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
      width: ResponsiveLayout.isMobile(context) ? double.infinity : 280,
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

class _RoleShowcase extends StatefulWidget {
  const _RoleShowcase();

  @override
  State<_RoleShowcase> createState() => _RoleShowcaseState();
}

class _RoleShowcaseState extends State<_RoleShowcase> {
  int _activeTab = 0;

  final List<Map<String, dynamic>> _tabsData = [
    {
      'role': 'For Administrators',
      'title': 'Take Control of the Ledger',
      'subtitle': 'Spend less time responding to messages and more time running your group.',
      'icon': Icons.admin_panel_settings_rounded,
      'benefits': [
        'Record contributions and manage recurring monthly fees or events in 3 clicks.',
        'Send automatic push notifications & reminders to members with outstanding dues.',
        'Generate and share beautiful event summaries in PDF or image format.',
      ],
    },
    {
      'role': 'For Members',
      'title': 'Track Where Every Cent Goes',
      'subtitle': 'Total transparency at your fingertips. No more guessing the group balance.',
      'icon': Icons.people_rounded,
      'benefits': [
        'Access public links to view target progress, paid/unpaid statuses, and expenses.',
        'Get official digital receipts instantly when your contribution is recorded.',
        'View the live net balance showing contributions minus expense deductions.',
      ],
    },
    {
      'role': 'For Auditors',
      'title': 'Audit-Ready in Seconds',
      'subtitle': 'Remove administrative hurdles and financial mix-ups completely.',
      'icon': Icons.fact_check_rounded,
      'benefits': [
        'Export comprehensive PDF summaries and transaction histories instantly.',
        'Verify transaction logs, receipts, and individual member statuses.',
        'Eliminate bookkeeping errors with structured community ledgers.',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final primaryColor = AppColors.primary(context);
    final currentTab = _tabsData[_activeTab];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 48,
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCard.withValues(alpha: 0.1)
          : AppColors.lightBackground.withValues(alpha: 0.2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Text(
              'Customized for Your Community Role',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Tab bar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(_tabsData.length, (index) {
                final isSelected = _activeTab == index;
                return ChoiceChip(
                  label: Text(_tabsData[index]['role']),
                  selected: isSelected,
                  selectedColor: primaryColor.withValues(alpha: 0.2),
                  backgroundColor: AppColors.card(context),
                  labelStyle: TextStyle(
                    color: isSelected ? primaryColor : AppColors.textSecondary(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _activeTab = index);
                    }
                  },
                );
              }),
            ),
            const SizedBox(height: 48),

            // Tab Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey<int>(_activeTab),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTabHeader(currentTab, primaryColor),
                          const SizedBox(height: 24),
                          ..._buildBenefitsList(currentTab['benefits']),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTabHeader(currentTab, primaryColor),
                                const SizedBox(height: 24),
                                ..._buildBenefitsList(currentTab['benefits']),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48),
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              currentTab['icon'],
                              size: 64,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(Map<String, dynamic> currentTab, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentTab['title'],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          currentTab['subtitle'],
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBenefitsList(List<dynamic> benefits) {
    return benefits.map<Widget>((benefit) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: AppColors.primary(context), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                benefit,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _AdminPainSection extends StatelessWidget {
  const _AdminPainSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = AppColors.primary(context);

    final painPoints = [
      'Manually verifying and tracking WhatsApp groups for payment receipts.',
      'Constantly updating complex spreadsheets for recurring monthly club or college fees.',
      'Deducting expenses and calculating the final net balance by hand.',
      'Individually messaging members to remind them about unpaid contributions.',
      'Extracting receipts and compiling event summaries manually when requested.',
      'Answering endless messages asking "Who has paid?" and "How much is collected?".',
    ];

    final solutionPoints = [
      'Once the admin marks a member as paid, the member can instantly download their receipt.',
      'Admins track recurring monthly tracks or event contributions in one dashboard.',
      'Expenses are automatically deducted, showing real-time net balances instantly.',
      'Send targeted push reminders to members with outstanding dues in one tap.',
      'Generate and share clean event summaries in PDF or image format instantly.',
      'Share a secure public link so anyone can view target progress and paid/unpaid lists.',
    ];

    Widget buildCard({
      required String title,
      required List<String> items,
      required Color color,
      required IconData headerIcon,
      required IconData itemIcon,
      required bool isNegative,
    }) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isNegative
                ? AppColors.border(context)
                : color.withValues(alpha: 0.3),
            width: isNegative ? 1.0 : 1.5,
          ),
          boxShadow: isNegative
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(headerIcon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Icon(
                          itemIcon,
                          color: isNegative ? Colors.orange : color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 48,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            Text(
              'The Admin Burden: Manual vs. Automated',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Compare the manual efforts of traditional fund management against KoFund.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            isMobile
                ? Column(
                    children: [
                      buildCard(
                        title: 'Without KoFund (Manual)',
                        items: painPoints,
                        color: Colors.grey,
                        headerIcon: Icons.warning_amber_rounded,
                        itemIcon: Icons.remove_circle_outline_rounded,
                        isNegative: true,
                      ),
                      const SizedBox(height: 32),
                      buildCard(
                        title: 'With KoFund (Automated)',
                        items: solutionPoints,
                        color: primaryColor,
                        headerIcon: Icons.bolt_rounded,
                        itemIcon: Icons.check_circle_outline_rounded,
                        isNegative: false,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: buildCard(
                          title: 'Without KoFund (Manual)',
                          items: painPoints,
                          color: Colors.grey,
                          headerIcon: Icons.warning_amber_rounded,
                          itemIcon: Icons.remove_circle_outline_rounded,
                          isNegative: true,
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: buildCard(
                          title: 'With KoFund (Automated)',
                          items: solutionPoints,
                          color: primaryColor,
                          headerIcon: Icons.bolt_rounded,
                          itemIcon: Icons.check_circle_outline_rounded,
                          isNegative: false,
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

class _FAQSection extends StatefulWidget {
  const _FAQSection();

  @override
  State<_FAQSection> createState() => _FAQSectionState();
}

class _FAQSectionState extends State<_FAQSection> {
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final List<_FAQItem> _faqs = [
    _FAQItem(
      question: 'Who can use KoFund?',
      answer: 'KoFund is designed for anyone managing money jointly. This includes mosque committees, local event organizers, student organizations, charity collections, family savings pools, housing societies, clubs, and college groups.',
      category: 'general',
    ),
    _FAQItem(
      question: 'Can I track monthly contributions?',
      answer: 'Yes! KoFund is built to track both one-off event targets and recurring monthly contributions, making it perfect for clubs, college committees, or residential societies.',
      category: 'usage',
    ),
    _FAQItem(
      question: 'How do members verify their payments?',
      answer: 'Once an admin records a contribution, members instantly receive a digital receipt. They can download it directly from the app to verify their payment.',
      category: 'usage',
    ),
    _FAQItem(
      question: 'Can members view event details without logging in?',
      answer: 'Yes. Admins can generate a secure public link for an event. Anyone with this link can view the contribution list (who paid and who did not), expense logs, target metrics, and the net balance.',
      category: 'general',
    ),
    _FAQItem(
      question: 'Is my data secure?',
      answer: 'Absolutely. We use Firebase Authentication to secure member logins and cloud security rules to ensure only approved committee members can edit or access community records.',
      category: 'security',
    ),
    _FAQItem(
      question: 'Does it support offline access?',
      answer: 'Yes! KoFund supports basic local caching so users can view data offline when an internet connection is unstable.',
      category: 'usage',
    ),
    _FAQItem(
      question: 'What happens if I delete my account?',
      answer: 'Deleting your account is permanent. All personal details, community memberships, and individual contribution history will be permanently wiped. Ledger entries made on behalf of the community are preserved to keep group records accurate, but all identifying member details are permanently decoupled. You can delete your account instantly in your web app settings or by emailing delete-account@kofund.web.app.',
      category: 'security',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = AppColors.primary(context);

    // Filtering logic
    final filteredFaqs = _faqs.where((faq) {
      final matchesSearch = faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'all' || faq.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 48,
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
            const SizedBox(height: 32),

            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search FAQ...',
                prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                filled: true,
                fillColor: AppColors.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCategoryChip('all', 'All Topics'),
                _buildCategoryChip('general', 'General'),
                _buildCategoryChip('security', 'Security'),
                _buildCategoryChip('usage', 'Usage'),
              ],
            ),
            const SizedBox(height: 32),

            // FAQ List
            filteredFaqs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      'No matching FAQs found.',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredFaqs.length,
                    itemBuilder: (context, index) {
                      final faq = filteredFaqs[index];
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

  Widget _buildCategoryChip(String cat, String label) {
    final isSelected = _selectedCategory == cat;
    final primaryColor = AppColors.primary(context);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor.withValues(alpha: 0.2),
      backgroundColor: AppColors.card(context),
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : AppColors.textSecondary(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedCategory = cat);
        }
      },
    );
  }
}

class _FAQItem {
  final String question;
  final String answer;
  final String category;

  _FAQItem({required this.question, required this.answer, required this.category});
}
