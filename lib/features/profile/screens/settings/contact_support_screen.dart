// lib/features/profile/screens/settings/contact_support_screen.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

Future<void> _launchEmail(BuildContext context) async {
  final email = 'kofundapp@gmail.com';
  final subject = 'Kofund App Support';
  final body = 'Hello Kofund Support,\n\nI need help with:';
  
  final nativeUrl = Uri.parse('mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
  
  debugPrint('Launching email URL: $nativeUrl');
  
  try {
    // Try to launch directly
    final result = await launchUrl(
      nativeUrl,
      mode: LaunchMode.externalApplication,
    );
    
    debugPrint('Launch result: $result');
    
    if (!result) {
      debugPrint('LaunchUrl returned false, showing options');
      await Future.delayed(Duration(milliseconds: 300));
      _showEmailOptionsDialog(context, email, subject, body);
    }
  } catch (e) {
    debugPrint('LaunchUrl error: $e');
    await Future.delayed(Duration(milliseconds: 300));
    _showEmailOptionsDialog(context, email, subject, body);
  }
}

  void _showEmailOptionsDialog(BuildContext context, String email, String subject, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No email app found. Choose an option:'),
            const SizedBox(height: 16),
            Text(
              'Support Email:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            Text(
              email,
              style: TextStyle(
                color: AppColors.primary(context),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openGmailWeb(email, subject, body, context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail, size: 18),
                SizedBox(width: 8),
                Text('Open Gmail Web'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGmailWeb(String email, String subject, String body, BuildContext context) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    
    final gmailUrl = Uri.parse(
      'https://mail.google.com/mail/?view=cm'
      '&fs=1'
      '&tf=1'
      '&to=$email'
      '&su=$encodedSubject'
      '&body=$encodedBody'
    );
    
    debugPrint('Trying Gmail URL: $gmailUrl');
    
    try {
      await launchUrl(
        gmailUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Gmail web failed: $e');
      
      final outlookUrl = Uri.parse(
        'https://outlook.live.com/mail/0/deeplink/compose?to=$email&subject=$encodedSubject&body=$encodedBody'
      );
      
      try {
        await launchUrl(outlookUrl, mode: LaunchMode.externalApplication);
      } catch (e2) {
        debugPrint('Outlook also failed: $e2');
        await _copyEmailDetails(email, subject, body, context);
      }
    }
  }

  Future<void> _copyEmailDetails(String email, String subject, String body, BuildContext context) async {
    final text = 'To: $email\nSubject: $subject\n\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    
    if (context.mounted) {
      SnackbarHelper.showInfo(context, 'Email details copied to clipboard');
    }
  }

  void _launchPhone(BuildContext context) async {
    final phone = '+918157875032';
    final url = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await Clipboard.setData(ClipboardData(text: phone));
        if (context.mounted) {
          SnackbarHelper.showInfo(context, 'Phone number copied: $phone');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showInfo(context, 'Unable to make phone call');
      }
    }
  }

  void _openWhatsApp(BuildContext context) async {
    final phone = '918157875032';
    final message = 'Hello Kofund Support, I need help with:';
    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await Clipboard.setData(ClipboardData(text: phone));
        if (context.mounted) {
          SnackbarHelper.showInfo(context, 'WhatsApp number copied: $phone');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showInfo(context, 'Unable to open WhatsApp');
      }
    }
  }

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.textSecondary(context),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.textSecondary(context),
      ),
    );
  }
Widget _buildWhatsAppContactCard({
  required BuildContext context,
  required VoidCallback onTap,
}) {
  return ListTile(
    onTap: onTap,
    leading: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.whatsapp,
          size: 24,
          color: Colors.green,
        ),
      ),
    ),
    title: Text(
      'WhatsApp Support',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
      ),
    ),
    subtitle: Text(
      'Message us on WhatsApp',
      style: TextStyle(
        color: AppColors.textSecondary(context),
      ),
    ),
    trailing: Icon(
      Icons.arrow_forward_ios,
      size: 16,
      color: AppColors.textSecondary(context),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientSheetScaffold(
      title: 'Contact Support',
      body: SingleChildScrollView(
        child: Padding(
          padding: AppStyles.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
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
                        Icons.support_agent,
                        size: 48,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We\'re here to help!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Get in touch with our support team for any questions or issues.',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Contact Methods Ttitle
              Text(
                'Quick Contact Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap on any option to contact us directly',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 16),

              // Contact Options
              Card(
                color: AppColors.card(context),
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    _buildContactCard(
                      context: context,
                      icon: Icons.email_outlined,
                      title: 'Email Support',
                      subtitle: 'kofundapp@gmail.com',
                      color: Colors.blue,
                      onTap: () => _launchEmail(context),
                    ),
                    Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                    _buildWhatsAppContactCard(
                      context: context,
                      onTap: () => _openWhatsApp(context),
                    ),
                    Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                    _buildContactCard(
                      context: context,
                      icon: Icons.phone_outlined,
                      title: 'Phone Support',
                      subtitle: '+91 815 787 5032',
                      color: Colors.orange,
                      onTap: () => _launchPhone(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Support Information
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
                            Icons.access_time,
                            color: AppColors.primary(context),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Support Hours',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem('Monday - Friday', '9:00 AM - 6:00 PM'),
                      _buildInfoItem('Saturday', '10:00 AM - 2:00 PM'),
                      _buildInfoItem('Sunday', 'Closed'),
                      _buildInfoItem('Response Time', 'Within 24 hours'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    }
  }








