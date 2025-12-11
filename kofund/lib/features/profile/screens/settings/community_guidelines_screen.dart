// lib/features/profile/screens/settings/community_guidelines_screen.dart
import 'package:flutter/material.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Guidelines'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Welcome to Our Community!'),
            _buildParagraph(
              'These guidelines help ensure our community remains respectful, transparent, and trustworthy for all members.'
            ),
            
            _buildSectionHeader('1. Contribution Tracking'),
            _buildBulletPoint('✅ Record contributions accurately and promptly'),
            _buildBulletPoint('✅ Verify contribution amounts with recipients'),
            _buildBulletPoint('✅ Keep offline records for personal reference'),
            _buildBulletPoint('❌ Never falsify contribution records'),
            _buildBulletPoint('❌ Don\'t use the app for actual money transfers'),
            
            _buildSectionHeader('2. Member Responsibilities'),
            _buildBulletPoint('✅ Provide accurate personal information'),
            _buildBulletPoint('✅ Respect other members\' privacy'),
            _buildBulletPoint('✅ Report any discrepancies immediately'),
            _buildBulletPoint('✅ Communicate respectfully in app communications'),
            _buildBulletPoint('❌ No harassment, discrimination, or abusive behavior'),
            
            _buildSectionHeader('3. Admin Responsibilities'),
            _buildBulletPoint('✅ Maintain accurate contribution records'),
            _buildBulletPoint('✅ Address member concerns promptly'),
            _buildBulletPoint('✅ Ensure data privacy and security'),
            _buildBulletPoint('✅ Resolve disputes fairly and transparently'),
            _buildBulletPoint('❌ No favoritism or biased record-keeping'),
            
            _buildSectionHeader('4. Data Accuracy & Verification'),
            _buildParagraph(
              'This app is designed for TRACKING purposes only. All cash contributions should be handled offline and verified in person.'
            ),
            _buildBulletPoint('🔍 Double-check contribution amounts'),
            _buildBulletPoint('📝 Keep personal receipts or records'),
            _buildBulletPoint('🕒 Report discrepancies within 7 days'),
            _buildBulletPoint('👥 Resolve issues through community discussion'),
            
            _buildSectionHeader('5. Dispute Resolution'),
            _buildNumberedPoint('1. Discuss the issue directly with involved parties'),
            _buildNumberedPoint('2. Escalate to community admin if unresolved'),
            _buildNumberedPoint('3. Provide evidence (if available)'),
            _buildNumberedPoint('4. Community voting for major disputes'),
            _buildNumberedPoint('5. Final decision by admin committee'),
            
            _buildSectionHeader('6. Privacy & Confidentiality'),
            _buildBulletPoint('✅ Respect other members\' personal information'),
            _buildBulletPoint('✅ Keep community financial matters confidential'),
            _buildBulletPoint('❌ Don\'t share others\' contribution data publicly'),
            _buildBulletPoint('❌ No screenshot or data sharing without consent'),
            
            _buildSectionHeader('7. App Usage Guidelines'),
            _buildBulletPoint('✅ Use for intended purpose only'),
            _buildBulletPoint('✅ Maintain one account per person'),
            _buildBulletPoint('✅ Keep login credentials secure'),
            _buildBulletPoint('❌ No automated scripts or bots'),
            _buildBulletPoint('❌ Don\'t attempt to exploit app vulnerabilities'),
            
            _buildSectionHeader('8. Consequences for Violations'),
            _buildParagraph(
              'Violations of these guidelines may result in:'
            ),
            _buildBulletPoint('⚠️ Warning and education for minor issues'),
            _buildBulletPoint('🔒 Temporary suspension for repeated violations'),
            _buildBulletPoint('🚫 Permanent removal for serious offenses'),
            _buildBulletPoint('👮 Legal action for fraudulent activities'),
            
            _buildSectionHeader('Important Disclaimers'),
            _buildParagraph(
              '📱 This app is a TRACKING TOOL only, not a financial institution.'
            ),
            _buildParagraph(
              '💵 All cash transactions occur OFFLINE between members.'
            ),
            _buildParagraph(
              '✅ Members are responsible for verifying their own contributions.'
            ),
            _buildParagraph(
              '🛡️ Admins strive for accuracy but cannot guarantee error-free records.'
            ),
            
            _buildSectionHeader('Need Help?'),
            _buildParagraph(
              'If you have questions or need to report an issue:'
            ),
            _buildBulletPoint('📧 Email: [Your Support Email]'),
            _buildBulletPoint('📞 Contact: [Your Community Admin]'),
            _buildBulletPoint('💬 Discuss in community meetings'),
            
            const SizedBox(height: 32),
            _buildAgreementSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildNumberedPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAgreementSection() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.handshake, size: 40, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              'Community Agreement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'By using this app, I agree to follow these community guidelines and contribute to maintaining a trustworthy environment for all members.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'I understand this app is for tracking purposes only',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}