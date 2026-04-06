import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kofund/core/constants/notification_types.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final Map<NotificationType, bool> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    for (final type in NotificationType.values) {
      final key = 'notification_${type.name}';
      _settings[type] = prefs.getBool(key) ?? true;
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveSetting(NotificationType type, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notification_${type.name}';
    await prefs.setBool(key, value);
    setState(() => _settings[type] = value);
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return 'Payment Notifications';
      case NotificationType.programUpdate:
        return 'Program Updates';
      case NotificationType.program: // 🆕 ADDED
        return 'New Programs';
      case NotificationType.adminAlert:
        return 'Admin Alerts';
      case NotificationType.system:
        return 'System Notifications';
      case NotificationType.announcement:
        return 'Announcements';
      case NotificationType.reminder:
        return 'Reminders';
      case NotificationType.approval:
        return 'Approval Notifications';
      case NotificationType.withdrawal:
        return 'Withdrawal Updates';
      case NotificationType.account:
        return 'Account Updates';
      case NotificationType.community:
        return 'Community Updates';
      case NotificationType.contribution:
        return 'Contribution Notifications';
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.programUpdate:
        return Icons.update;
      case NotificationType.program: // 🆕 ADDED
        return Icons.calendar_today;
      case NotificationType.adminAlert:
        return Icons.admin_panel_settings;
      case NotificationType.system:
        return Icons.warning;
      case NotificationType.announcement:
        return Icons.announcement;
      case NotificationType.reminder:
        return Icons.notifications_active;
      case NotificationType.approval:
        return Icons.check_circle;
      case NotificationType.withdrawal:
        return Icons.money_off;
      case NotificationType.account:
        return Icons.person;
      case NotificationType.community:
        return Icons.groups;
      case NotificationType.contribution:
        return Icons.currency_rupee;
    }
  }

  Color _getTypeIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return Colors.green;
      case NotificationType.programUpdate:
        return Colors.blue;
      case NotificationType.program: // 🆕 ADDED
        return Colors.deepPurple;
      case NotificationType.adminAlert:
        return Colors.red;
      case NotificationType.system:
        return Colors.orange;
      case NotificationType.announcement:
        return Colors.purple;
      case NotificationType.reminder:
        return Colors.amber;
      case NotificationType.approval:
        return Colors.teal;
      case NotificationType.withdrawal:
        return Colors.brown;
      case NotificationType.account:
        return Colors.indigo;
      case NotificationType.community:
        return Colors.cyan;
      case NotificationType.contribution:
        return Colors.lightGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GradientSheetScaffold(
        title: 'Notification Settings',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GradientSheetScaffold(
      title: 'Notification Settings',
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which notifications you want to receive',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),

        ...NotificationType.values.map((type) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getTypeIconColor(type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: _getTypeIconColor(type),
                  size: 20,
                ),
              ),
              title: Text(
                _getTypeLabel(type),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _getDescription(type),
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Switch(
                value: _settings[type] ?? true,
                onChanged: (value) => _saveSetting(type, value),
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Note: Critical notifications related to account security will always be sent.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  String _getDescription(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return 'Payment confirmations, failures, and receipts';
      case NotificationType.programUpdate:
        return 'Updates about programs you\'ve joined';
      case NotificationType.program: // 🆕 ADDED
        return 'Notifications when new programs are created';
      case NotificationType.adminAlert:
        return 'Important alerts for administrators only';
      case NotificationType.system:
        return 'System maintenance and technical updates';
      case NotificationType.announcement:
        return 'General announcements from KoFund';
      case NotificationType.reminder:
        return 'Payment due reminders and deadlines';
      case NotificationType.approval:
        return 'When your requests are approved or rejected';
      case NotificationType.withdrawal:
        return 'Withdrawal requests and status updates';
      case NotificationType.account:
        return 'Account security and profile updates';
      case NotificationType.community:
        return 'Community news and member activities';
      case NotificationType.contribution:
        return 'Contribution updates and confirmations';
    }
  }
}
