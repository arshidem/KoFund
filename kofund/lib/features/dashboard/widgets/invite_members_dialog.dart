// lib/features/community/widgets/invite_members_dialog.dart
// Premium, modern, UX-focused redesign (single cohesive model)

import 'package:flutter/material.dart';
import 'package:clipboard/clipboard.dart';
import 'package:kofund/core/constants/app_colors.dart';

class InviteMembersDialog extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String inviteCode;
  final String inviteLink;
  final Future<void> Function() onRegenerateCode;

  const InviteMembersDialog({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.inviteCode,
    required this.inviteLink,
    required this.onRegenerateCode,
  });

  @override
  State<InviteMembersDialog> createState() => _InviteMembersDialogState();
}

class _InviteMembersDialogState extends State<InviteMembersDialog>
    with SingleTickerProviderStateMixin {
  bool _copiedCode = false;
  bool _copiedLink = false;
  bool _regenerating = false;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _copyInviteCode() async {
    await FlutterClipboard.copy(widget.inviteCode);
    setState(() {
      _copiedCode = true;
      _copiedLink = false;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiedCode = false);
  }

  Future<void> _copyInviteLink() async {
    await FlutterClipboard.copy(widget.inviteLink);
    setState(() {
      _copiedLink = true;
      _copiedCode = false;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiedLink = false);
  }

  Future<void> _shareInviteLink() async {
    // Replace with share_plus if needed
    await _copyInviteLink();
  }

  Future<void> _handleRegenerateCode() async {
    setState(() => _regenerating = true);
    try {
      await widget.onRegenerateCode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(context);
    final secondary = AppColors.secondary(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.cardBackground(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  title: widget.communityName,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),

                _HeroInviteCode(
                  code: widget.inviteCode,
                  primary: primary,
                  copied: _copiedCode,
                  pulse: _pulseController,
                  onCopy: _copyInviteCode,
                ),

                const SizedBox(height: 28),

                _InviteLinkCard(
                  link: widget.inviteLink,
                  secondary: secondary,
                  copied: _copiedLink,
                  onCopy: _copyInviteLink,
                  onShare: _shareInviteLink,
                ),

                const SizedBox(height: 28),

                _RegenerateSection(
                  regenerating: _regenerating,
                  onRegenerate: _handleRegenerateCode,
                ),

                const SizedBox(height: 24),

                const _HowItWorks(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================== COMPONENTS ======================

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _Header({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite Members',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.close_rounded,
              color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }
}

class _HeroInviteCode extends StatelessWidget {
  final String code;
  final Color primary;
  final bool copied;
  final AnimationController pulse;
  final VoidCallback onCopy;

  const _HeroInviteCode({
    required this.code,
    required this.primary,
    required this.copied,
    required this.pulse,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.15), primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: primary.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.04).animate(
              CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                fontFamily: 'RobotoMono',
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCopy,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(copied ? Icons.check_circle : Icons.copy_rounded),
            label: Text(
              copied ? 'Copied to clipboard' : 'Copy Invite Code',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  final String link;
  final Color secondary;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _InviteLinkCard({
    required this.link,
    required this.secondary,
    required this.copied,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: LinearGradient(
      colors: [
        secondary.withOpacity(0.15),
        secondary.withOpacity(0.05),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    border: Border.all(
      color: secondary.withOpacity(0.25),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // rest of your widget stays EXACTLY the same

          Text(
            'Invite Link',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    link,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: Icon(copied
                      ? Icons.check_circle_rounded
                      : Icons.copy_rounded),
                  label: Text(copied ? 'Copied' : 'Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondary,
                    side: BorderSide(color: secondary.withOpacity(0.4)),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                  style: FilledButton.styleFrom(
                    backgroundColor: secondary,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegenerateSection extends StatelessWidget {
  final bool regenerating;
  final VoidCallback onRegenerate;

  const _RegenerateSection({
    required this.regenerating,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    if (regenerating) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Regenerating invite code...'),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onRegenerate,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Regenerate Invite Code'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.orange,
        side: BorderSide(color: Colors.orange.withOpacity(0.4)),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Step(number: '1', text: 'Share the invite code or link'),
          _Step(number: '2', text: 'They request to join via KoFund'),
          _Step(number: '3', text: 'Approve the request as admin'),
          _Step(number: '4', text: 'Member gets full community access'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
// ====================== END OF FILE ======================