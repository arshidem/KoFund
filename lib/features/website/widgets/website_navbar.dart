import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../auth/providers/app_auth_provider.dart';
import 'responsive_layout.dart';

class WebsiteNavbar extends StatelessWidget implements PreferredSizeWidget {
  const WebsiteNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  void _launchWebApp(BuildContext context, bool isLoggedIn) {
    if (isLoggedIn) {
      context.go('/splash');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    final isLoggedIn = authProvider.user != null;
    final isDark = themeProvider.isDarkMode;
    final primaryColor = AppColors.primary(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.background(context).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border(context).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Logo & Name
          GestureDetector(
            onTap: () => context.go('/'),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(9),
                  child: SvgPicture.asset(
                    'assets/logos/KoFund.svg',
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'KoFund',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Navigation Links (Desktop/Tablet)
          if (!ResponsiveLayout.isMobile(context)) ...[
            _NavBarLink(
              title: 'Home',
              onTap: () => context.go('/'),
            ),
            _NavBarLink(
              title: 'About',
              onTap: () => context.go('/about'),
            ),
            _NavBarLink(
              title: 'Support',
              onTap: () => context.go('/support'),
            ),
            _NavBarLink(
              title: 'Data Safety',
              onTap: () => context.go('/dataSafety'),
            ),
            const SizedBox(width: 16),
          ],

          // Theme Toggle (Desktop/Tablet only)
          if (!ResponsiveLayout.isMobile(context)) ...[
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: AppColors.textSecondary(context),
              ),
              onPressed: () {
                themeProvider.toggleTheme(!isDark);
              },
            ),
            const SizedBox(width: 8),
          ],

          // Open Web App Button (Desktop/Tablet)
          if (!ResponsiveLayout.isMobile(context))
            ElevatedButton(
              onPressed: () => _launchWebApp(context, isLoggedIn),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLoggedIn ? 'Go to Dashboard' : 'Open Web App',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.open_in_new_rounded, size: 14),
                ],
              ),
            )
          else
            // Menu Icon for mobile
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: AppColors.textPrimary(context),
              ),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
        ],
      ),
    );
  }
}

class _NavBarLink extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _NavBarLink({
    required this.title,
    required this.onTap,
  });

  @override
  State<_NavBarLink> createState() => _NavBarLinkState();
}

class _NavBarLinkState extends State<_NavBarLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: _isHovered ? FontWeight.bold : FontWeight.w500,
              color: _isHovered
                  ? AppColors.primary(context)
                  : AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class WebsiteDrawer extends StatelessWidget {
  const WebsiteDrawer({super.key});

  void _launchWebApp(BuildContext context, bool isLoggedIn) {
    if (isLoggedIn) {
      context.go('/splash');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLoggedIn = authProvider.user != null;
    final primaryColor = AppColors.primary(context);
    final isDark = themeProvider.isDarkMode;
    
    return Drawer(
      backgroundColor: AppColors.background(context),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KoFund',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _buildDrawerItem(context, 'Home', '/'),
              _buildDrawerItem(context, 'About KoFund', '/about'),
              _buildDrawerItem(context, 'Support / Contact', '/support'),
              _buildDrawerItem(context, 'Data Safety', '/dataSafety'),
              _buildDrawerItem(context, 'Privacy Policy', '/privacyPolicy'),
              _buildDrawerItem(context, 'Terms of Service', '/termsOfService'),
              _buildDrawerItem(context, 'Delete Account', '/deleteAccount'),
              const Spacer(),
              // Mobile Theme Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDark ? 'Light Mode' : 'Dark Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: AppColors.primary(context),
                    ),
                    onPressed: () {
                      themeProvider.toggleTheme(!isDark);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _launchWebApp(context, isLoggedIn);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLoggedIn ? 'Go to Dashboard' : 'Open Web App',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.open_in_new_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final url = Uri.parse('https://drive.google.com/file/d/1jQEGYyfAZjnt9L8PPqYpANaizGaq0gq0/view?usp=sharing');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Download Android App',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.go(path);
        },
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
