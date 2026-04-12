import 'package:kofund/core/widgets/premium_switch.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
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
      case NotificationType.program:
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
      case NotificationType.pendingUser:
        return 'New Member Requests';
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.programUpdate:
        return Icons.update;
      case NotificationType.program:
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
      case NotificationType.pendingUser:
        return Icons.person_add_rounded;
    }
  }

  Color _getTypeIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return Colors.green;
      case NotificationType.programUpdate:
        return Colors.blue;
      case NotificationType.program:
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
      case NotificationType.pendingUser:
        return Colors.orangeAccent;
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Preferences'),
          _buildSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  'Choose which notifications you want to receive. Critical security alerts are always sent.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ),
              _buildItemDivider(),
              ...NotificationType.values.expand((type) => [
                    _buildNotificationToggle(type),
                    if (type != NotificationType.values.last) _buildItemDivider(),
                  ]),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context).withValues(alpha: 0.4),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildItemDivider() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      endIndent: 20,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
    );
  }

  Widget _buildNotificationToggle(NotificationType type) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getTypeIconColor(type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(type),
              color: _getTypeIconColor(type),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTypeLabel(type),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getDescription(type),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PremiumSwitch(
            value: _settings[type] ?? true,
            onChanged: (value) => _saveSetting(type, value),
            activeColor: AppColors.primary(context),
          ),
        ],
      ),
    );
  }

  String _getDescription(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return 'Payment confirmations, failures, and receipts';
      case NotificationType.programUpdate:
        return 'Updates about programs you\'ve joined';
      case NotificationType.program:
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
      case NotificationType.pendingUser:
        return 'Alerts for new member join requests (Admins only)';
    }
  }
}
