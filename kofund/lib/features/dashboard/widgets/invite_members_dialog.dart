// lib/features/community/widgets/invite_members_dialog.dart
import 'package:flutter/material.dart';
import 'package:clipboard/clipboard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kofund/core/constants/app_colors.dart';

class InviteMembersDialog extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String inviteCode;
  final String inviteLink;
  final VoidCallback onRegenerateCode;
  
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

class _InviteMembersDialogState extends State<InviteMembersDialog> {
  bool _copiedCode = false;
  bool _copiedLink = false;
  bool _regenerating = false;

  void _copyInviteCode() async {
    await FlutterClipboard.copy(widget.inviteCode);
    setState(() {
      _copiedCode = true;
      _copiedLink = false;
    });
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _copiedCode = false;
      });
    }
  }

  void _copyInviteLink() async {
    await FlutterClipboard.copy(widget.inviteLink);
    setState(() {
      _copiedLink = true;
      _copiedCode = false;
    });
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _copiedLink = false;
      });
    }
  }

  Future<void> _handleRegenerateCode() async {
    setState(() {
      _regenerating = true;
    });
    
    try {
      widget.onRegenerateCode();
    } finally {
      if (mounted) {
        setState(() {
          _regenerating = false;
        });
      }
    }
  }

  // ✅ SIMPLIFIED: Remove all app_links complexity
  Future<void> _launchInviteLink() async {
    final Uri url = Uri.parse(widget.inviteLink);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );
      } else {
        // Fallback: Copy the link
        _copyInviteLink();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Link copied: ${widget.inviteCode}'),
            ),
          );
        }
      }
    } catch (e) {
      // Just copy if launch fails
      _copyInviteLink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: AppColors.cardBackground(context),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invite to ${widget.communityName}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Share this code or link with others to invite them to join your community',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              
              // Invite Code Section
              _buildInviteCodeSection(),
              const SizedBox(height: 24),
              
              // Invite Link Section
              _buildInviteLinkSection(),
              const SizedBox(height: 24),
              
              // Regenerate Button
              if (!_regenerating)
                ElevatedButton(
                  onPressed: _handleRegenerateCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    foregroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 8),
                      Text('Regenerate Invite Code'),
                    ],
                  ),
                ),
              
              if (_regenerating)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.orange),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Regenerating code...',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Instructions
              _buildInstructions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Code',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary(context).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                widget.inviteCode,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary(context),
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _copyInviteCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _copiedCode ? Icons.check : Icons.content_copy,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _copiedCode ? 'Code Copied!' : 'Copy Invite Code',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInviteLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Link',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _launchInviteLink,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondary(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondary(context).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 16,
                      color: AppColors.primary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.inviteLink,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary(context),
                          height: 1.4,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap to open in KoFund app',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _copyInviteLink,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary(context),
                          side: BorderSide(color: AppColors.secondary(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _copiedLink ? Icons.check : Icons.content_copy,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _copiedLink ? 'Copied!' : 'Copy Link',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _launchInviteLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary(context),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Open Link',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'How it works:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            number: '1',
            text: 'Share the invite code or link with others',
          ),
          _buildInstructionStep(
            number: '2',
            text: 'They can click the link to open the KoFund app',
          ),
          _buildInstructionStep(
            number: '3',
            text: 'The app will show the join screen with code pre-filled',
          ),
          _buildInstructionStep(
            number: '4',
            text: 'You will receive a join request to approve',
          ),
          _buildInstructionStep(
            number: '5',
            text: 'Once approved, they can access all community features',
          ),
          const SizedBox(height: 12),
          Text(
            'Note: All new members require admin approval before they can access community features.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep({required String number, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}