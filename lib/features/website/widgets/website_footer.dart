import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_colors.dart';
import 'responsive_layout.dart';

class WebsiteFooter extends StatelessWidget {
  const WebsiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final textTheme = Theme.of(context).textTheme;

    final logoSlogan = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary(context),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(
                'assets/logos/KoFund.svg',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'KoFund',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Manage Community Funds Without WhatsApp Confusion.',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );

    final legalLinks = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legal',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 16),
        _FooterLink(
          title: 'Privacy Policy',
          onTap: () => context.go('/privacyPolicy'),
        ),
        _FooterLink(
          title: 'Terms of Service',
          onTap: () => context.go('/termsOfService'),
        ),
        _FooterLink(
          title: 'Delete Account',
          onTap: () => context.go('/deleteAccount'),
        ),
      ],
    );

    final resourceLinks = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resources',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 16),
        _FooterLink(
          title: 'Data Safety',
          onTap: () => context.go('/dataSafety'),
        ),
        _FooterLink(
          title: 'Support',
          onTap: () => context.go('/support'),
        ),
        _FooterLink(
          title: 'About Us',
          onTap: () => context.go('/about'),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(
          top: BorderSide(
            color: AppColors.border(context).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logoSlogan,
                const SizedBox(height: 32),
                legalLinks,
                const SizedBox(height: 32),
                resourceLinks,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isDesktop ? 2 : 4,
                  child: logoSlogan,
                ),
                if (isDesktop) const Spacer(),
                Expanded(
                  flex: isDesktop ? 1 : 3,
                  child: legalLinks,
                ),
                Expanded(
                  flex: isDesktop ? 1 : 3,
                  child: resourceLinks,
                ),
              ],
            ),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 24),
          isMobile
              ? Column(
                  children: [
                    Text(
                      '© ${DateTime.now().year} KoFund. All rights reserved.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Built with ',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                        const Icon(
                          Icons.favorite_rounded,
                          color: Colors.red,
                          size: 12,
                        ),
                        Text(
                          ' using Flutter',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '© ${DateTime.now().year} KoFund. All rights reserved.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary(context),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Built with ',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                        const Icon(
                          Icons.favorite_rounded,
                          color: Colors.red,
                          size: 12,
                        ),
                        Text(
                          ' using Flutter',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _FooterLink({
    required this.title,
    required this.onTap,
  });

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
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
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
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
