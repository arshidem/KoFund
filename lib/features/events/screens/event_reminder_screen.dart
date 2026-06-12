import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:kofund/features/events/providers/event_provider.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:kofund/core/services/reminder_service.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/widgets/custom_button.dart';
import 'package:kofund/core/utils/dialog_helper.dart';

class EventRemindersScreen extends StatefulWidget {
  final EventModel event;

  const EventRemindersScreen({super.key, required this.event});

  @override
  State<EventRemindersScreen> createState() => _emindersScreenState();
}

class _emindersScreenState extends State<EventRemindersScreen> {
  late EventModel _event;
  final TextEditingController _daysController = TextEditingController();
  final FocusNode _daysFocus = FocusNode();
  String _selectedFrequency = 'monthly';
  DateTime? _selectedDate;
  bool _enableReminders = false;
  bool _isSendingReminder = false;
  bool _isSavingSettings = false;
  late ReminderService _reminderService;
  
  final TextEditingController _customTitleController = TextEditingController();
  final TextEditingController _customMessageController = TextEditingController();
  
  bool _enableRetries = false;
  final TextEditingController _retryDaysController = TextEditingController();
  final FocusNode _retryDaysFocus = FocusNode();
  
  bool _enableEscalation = false;
  final TextEditingController _escalationDaysController = TextEditingController();
  final FocusNode _escalationDaysFocus = FocusNode();

  int _selectedWeekday = DateTime.monday;
  int _selectedMonthDay = 1;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _enableReminders = _event.enableAutoReminders;
    _selectedFrequency = _event.reminderFrequency;
    _daysController.text = _event.reminderDaysBefore.toString();
    _customTitleController.text = _event.customReminderTitle ?? '';
    _customMessageController.text = _event.customReminderMessage ?? '';
    _enableRetries = _event.enableReminderRetries;
    _retryDaysController.text = _event.retryDaysAfter.toString();
    _enableEscalation = _event.enableAdminEscalation;
    _escalationDaysController.text = _event.escalationDaysAfter.toString();
    _reminderService = ReminderService();

    if (_event.reminderFrequency == 'weekly' && _event.firstPaymentDueDate != null) {
      _selectedWeekday = _event.firstPaymentDueDate!.weekday;
    } else {
      _selectedWeekday = DateTime.monday;
    }
    
    if (_event.reminderFrequency == 'monthly' && _event.firstPaymentDueDate != null) {
      _selectedMonthDay = _event.firstPaymentDueDate!.day;
    } else {
      _selectedMonthDay = 1;
    }
    
    _daysController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _daysController.dispose();
    _daysFocus.dispose();
    _customTitleController.dispose();
    _customMessageController.dispose();
    _retryDaysController.dispose();
    _retryDaysFocus.dispose();
    _escalationDaysController.dispose();
    _escalationDaysFocus.dispose();
    super.dispose();
  }



  Future<void> _sendRealReminder() async {
    if (_isSendingReminder) {
      SnackbarHelper.showInfo(context, 'Please wait, reminder is already being sent');
      return;
    }
    
    _isSendingReminder = true;
    
    try {
      // ✅ NEW: Prevent multiple executions within the same day
      if (_event.lastReminderSent != null) {
        final lastSent = _event.lastReminderSent!.toDate();
        final now = DateTime.now();
        if (lastSent.year == now.year && 
            lastSent.month == now.month && 
            lastSent.day == now.day) {
          SnackbarHelper.showInfo(
            context, 
            'Reminders have already been sent today (at ${DateFormat.jm().format(lastSent)}). '
            'Manual execution is limited to once per day.'
          );
          _isSendingReminder = false;
          return;
        }
      }
      
      final confirm = await DialogHelper.showConfirmationDialog(
        context,
        title: 'Send Reminder?',
        message: 'This will send actual push notifications to all participants with unpaid contributions. Continue?',
        confirmLabel: 'Send',
        cancelLabel: 'Cancel',
        icon: Icons.notifications_active_rounded,
      );
      
      if (confirm != true) {
        _isSendingReminder = false;
        return;
      }
      
      _showLoadingDialog('Sending reminders...');
      
      final result = await _reminderService.sendContributionReminders(
        communityId: _event.communityId,
        eventId: _event.eventId,
        sendTest: false,
      );
      
      if (mounted) Navigator.pop(context); // Close loading
      
      if (result['success'] == true) {
        final remindersSent = result['remindersSent'] ?? 0;
        String message = '✅ Real reminders sent successfully';
        if (remindersSent > 0) message += ' to $remindersSent participants';
        
        SnackbarHelper.showSuccess(context, message);
        await _loadReminderData();
        _showReminderResults(result);
      } else {
        SnackbarHelper.showError(context, 'Failed: ${result['message']}');
      }
      
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        SnackbarHelper.showError(context, 'Failed to send reminder: $e');
      }
    } finally {
      _isSendingReminder = false;
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary(context)),
              const SizedBox(height: 20),
              Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary(context)),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textSecondary(context).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildReminderToggle() {
    return _buildCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(
              'Automation Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            subtitle: Text(
              _enableReminders 
                ? 'Automatic reminders are ACTIVE'
                : 'Automatic reminders are DISABLED',
              style: TextStyle(
                color: _enableReminders ? AppColors.primary(context) : AppColors.textSecondary(context),
                fontWeight: _enableReminders ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            value: _enableReminders,
            activeThumbColor: AppColors.primary(context),
            onChanged: (value) {
              HapticHelper.medium();
              setState(() {
                _enableReminders = value;
              });
            },
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_enableReminders ? AppColors.primary(context) : Colors.grey).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _enableReminders ? Icons.notifications_active : Icons.notifications_off,
                color: _enableReminders ? AppColors.primary(context) : Colors.grey,
                size: 24,
              ),
            ),
          ),
          if (_enableReminders && _event.nextReminderDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppDimensions.radiusLarge)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, size: 16, color: AppColors.primary(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next scheduled: ${DateFormat('MMMM dd, yyyy').format(_event.nextReminderDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Monday';
      case DateTime.tuesday: return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday: return 'Thursday';
      case DateTime.friday: return 'Friday';
      case DateTime.saturday: return 'Saturday';
      case DateTime.sunday: return 'Sunday';
      default: return '';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  DateTime? _calculateFirstPaymentDueDate() {
    if (_selectedFrequency == 'custom') return null;
    
    final now = DateTime.now();
    if (_selectedFrequency == 'weekly') {
      int daysToAdd = _selectedWeekday - now.weekday;
      if (daysToAdd <= 0) {
        daysToAdd += 7; // Ensure next week
      }
      return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
    } else if (_selectedFrequency == 'monthly') {
      // If target day is in the future this month
      if (_selectedMonthDay > now.day) {
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final actualDay = _selectedMonthDay > daysInMonth ? daysInMonth : _selectedMonthDay;
        return DateTime(now.year, now.month, actualDay);
      } else {
        // Next month
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final actualDay = _selectedMonthDay > daysInNextMonth ? daysInNextMonth : _selectedMonthDay;
        return DateTime(nextYear, nextMonth, actualDay);
      }
    }
    return null;
  }

  Widget _buildScheduleSummary() {
    if (!_enableReminders) return const SizedBox.shrink();

    String text = '';
    IconData icon = Icons.info_outline;

    if (_selectedFrequency == 'custom') {
      final count = _event.contributionReminderDates.length;
      text = count == 0
          ? 'No one-time reminder dates scheduled yet. Pick a date below to get started.'
          : 'Reminders will be sent on the $count specific dates listed below.';
    } else {
      final frequencyLabel = _selectedFrequency == 'monthly' ? 'monthly' : 'weekly';
      
      final computedDueDate = _calculateFirstPaymentDueDate();
      if (computedDueDate == null) {
        text = 'Reminders will run on a $frequencyLabel cycle.';
      } else {
        final formattedDate = DateFormat('MMM dd, yyyy').format(computedDueDate);
        
        final selectionDesc = _selectedFrequency == 'weekly'
            ? 'every ${_getWeekdayName(_selectedWeekday)}'
            : 'on the ${_selectedMonthDay}${_getDaySuffix(_selectedMonthDay)} of every month';
        
        text = '🔔 Reminders will automatically go out $selectionDesc (Next reminder: $formattedDate).';
        icon = Icons.auto_awesome;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary(context).withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How often should reminders be sent?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildChoiceChip('monthly', 'Monthly'),
              _buildChoiceChip('weekly', 'Weekly'),
              _buildChoiceChip('custom', 'Specific Dates'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String value, String label) {
    final isSelected = _selectedFrequency == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticHelper.light();
          setState(() => _selectedFrequency = value);
        }
      },
      selectedColor: AppColors.primary(context).withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary(context),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary(context) : AppColors.textSecondary(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        side: BorderSide(
          color: isSelected ? AppColors.primary(context) : AppColors.border(context),
        ),
      ),
      backgroundColor: AppColors.surface(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  void _showDaySelectorDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFrequency == 'weekly' ? 'Select Weekday' : 'Select Day of Month',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary(context), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedFrequency == 'weekly')
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final weekday = index + 1;
                    final isSelected = _selectedWeekday == weekday;
                    final name = _getWeekdayName(weekday);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedWeekday = weekday;
                        });
                        Navigator.pop(context);
                        HapticHelper.selection();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary(context) : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary(context) : AppColors.border(context),
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (_selectedFrequency == 'monthly')
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: 28,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isSelected = _selectedMonthDay == day;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMonthDay = day;
                        });
                        Navigator.pop(context);
                        HapticHelper.selection();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary(context) : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary(context) : AppColors.border(context),
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsDetail() {
    final selectionText = _selectedFrequency == 'weekly'
        ? _getWeekdayName(_selectedWeekday)
        : '${_selectedMonthDay}${_getDaySuffix(_selectedMonthDay)}';

    return _buildCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFrequency == 'weekly' ? 'Weekly Reminder Day' : 'Monthly Reminder Day',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedFrequency == 'weekly'
                      ? 'Select the day of the week to send reminders'
                      : 'Select the day of the month to send reminders',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: _showDaySelectorDialog,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 18, color: AppColors.primary(context)),
                  const SizedBox(width: 8),
                  Text(
                    selectionText,
                    style: TextStyle(
                      color: AppColors.primary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.primary(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDatesSection() {
    return Column(
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Specific Reminder Date',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Schedule a one-time notification for a future date',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickReminderDate,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: AppColors.border(context), style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: AppColors.primary(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('MMMM dd, yyyy').format(_selectedDate!)
                              : 'Select a custom date...',
                          style: TextStyle(
                            color: _selectedDate != null ? AppColors.textPrimary(context) : AppColors.textTertiary(context),
                            fontWeight: _selectedDate != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_selectedDate != null)
                        IconButton(
                          onPressed: _addReminderDate,
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_event.contributionReminderDates.isNotEmpty) ...[
          _buildSectionHeader('Scheduled Reminders', icon: Icons.history),
          _buildCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _event.contributionReminderDates.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border(context).withValues(alpha: 0.5)),
              itemBuilder: (context, index) {
                final date = _event.contributionReminderDates[index];
                final isPast = date.isBefore(DateTime.now());
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPast ? Colors.grey : Colors.orange).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPast ? Icons.done_all : Icons.notifications_active,
                      color: isPast ? Colors.grey : Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    DateFormat('EEEE, MMM dd, yyyy').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: isPast ? TextDecoration.lineThrough : null,
                      color: isPast ? AppColors.textSecondary(context) : AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    isPast ? 'Already sent or passed' : '${date.difference(DateTime.now()).inDays} days from now',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.error(context).withValues(alpha: 0.7)),
                    onPressed: () {
                      HapticHelper.light();
                      _removeReminderDate(date);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _clearAllReminders,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear All Scheduled Dates'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error(context)),
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancedFeatures() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Notification Message',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Override the default push notification text',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _customTitleController,
            decoration: InputDecoration(
              labelText: 'Custom Title (Optional)',
              filled: true,
              fillColor: AppColors.background(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: BorderSide(color: AppColors.primary(context), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customMessageController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Custom Body Message (Optional)',
              filled: true,
              fillColor: AppColors.background(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: BorderSide(color: AppColors.primary(context), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _pickFirstPaymentDate() async {
    HapticHelper.selection();
    final picked = await showDatePicker(
      context: context,
      initialDate: _event.firstPaymentDueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary(context)),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _event = _event.copyWith(firstPaymentDueDate: picked);
      });
    }
  }

  Future<void> _pickReminderDate() async {
    HapticHelper.selection();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addReminderDate() {
    if (_selectedDate == null) return;
    HapticHelper.success();
    final newDates = List<DateTime>.from(_event.contributionReminderDates)
      ..add(_selectedDate!)
      ..sort();
    
    setState(() {
      _event = _event.copyWith(contributionReminderDates: newDates);
      _selectedDate = null;
    });
    
    SnackbarHelper.showSuccess(context, 'Reminder date added');
  }

  void _removeReminderDate(DateTime date) {
    final newDates = List<DateTime>.from(_event.contributionReminderDates)
      ..removeWhere((eventId) => eventId.isAtSameMomentAs(date));
    
    setState(() {
      _event = _event.copyWith(contributionReminderDates: newDates);
    });
    
    SnackbarHelper.showSuccess(context, 'Reminder date removed');
  }

  void _clearAllReminders() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
        title: const Text('Clear All Reminders?'),
        content: const Text('Are you sure you want to remove all scheduled reminder dates?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              HapticHelper.heavy();
              Navigator.pop(context);
              setState(() {
                _event = _event.copyWith(contributionReminderDates: []);
              });
              SnackbarHelper.showSuccess(context, 'All reminders cleared');
            },
            child: Text('Clear', style: TextStyle(color: AppColors.error(context), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _saveReminders() async {
    if (_isSavingSettings) return;
    setState(() {
      _isSavingSettings = true;
    });
    try {
      HapticHelper.medium();
      final eventProvider = context.read<EventProvider>();
      
      final calculatedDueDate = _calculateFirstPaymentDueDate();
      
      final update = _event.copyWith(
        enableAutoReminders: _enableReminders,
        reminderDaysBefore: 0,
        reminderFrequency: _selectedFrequency,
        firstPaymentDueDate: calculatedDueDate,
      );
      
      final nextReminderDate = _enableReminders 
          ? update.calculateNextReminderDate()
          : null;
      
      await eventProvider.updateReminderSettings(
        eventId: _event.eventId,
        enableAutoReminders: _enableReminders,
        reminderDaysBefore: 0,
        reminderFrequency: _selectedFrequency,
        contributionReminderDates: _event.contributionReminderDates,
        firstPaymentDueDate: calculatedDueDate,
        nextReminderDate: nextReminderDate,
        customReminderTitle: _customTitleController.text.trim().isEmpty ? null : _customTitleController.text.trim(),
        customReminderMessage: _customMessageController.text.trim().isEmpty ? null : _customMessageController.text.trim(),
        enableReminderRetries: _enableRetries,
        retryDaysAfter: int.tryParse(_retryDaysController.text) ?? 3,
        enableAdminEscalation: _enableEscalation,
        escalationDaysAfter: int.tryParse(_escalationDaysController.text) ?? 3,
      );
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Reminder settings saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to save: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSettings = false;
        });
      }
    }
  }

  void _showReminderResults(Map<String, dynamic> data) {
    final isTest = data['isTest'] ?? false;
    final success = data['success'] ?? false;
    final message = data['message'] ?? 'Completed';
    
    if (!success) {
      SnackbarHelper.showError(context, 'Failed: $message');
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusExtraLarge)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.task_alt, color: AppColors.success(context)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTest ? 'Test Run Results' : 'Execution Success',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          message,
                          style: TextStyle(color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildResultRow('Reminders Sent', '${data['remindersSent'] ?? 0}'),
              _buildResultRow('Notifications Root', '${data['notificationsCreated'] ?? 0}'),
              _buildResultRow('Batch Size', '${data['eventsProcessed'] ?? 0} events'),
              const Divider(height: 32),
              if (data['results'] != null) ...[
                const Text('Breakdown by event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                for (final result in (data['results'] as List).cast<Map<String, dynamic>>())
                  _builResultItem(result),
              ],
              const SizedBox(height: 32),
              if (isTest)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Test mode was active. No actual push notifications were delivered to users.',
                          style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              CustomButton(
                onPressed: () => Navigator.pop(context),
                text: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _builResultItem(Map<String, dynamic> result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result['name'] ?? 'Untitled event', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSmallResultRow('Target Users', '${result['participantsNeedingReminders'] ?? 0}'),
          _buildSmallResultRow('Push Sent', '${result['pushNotificationsSent'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 15)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSmallResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _loadReminderData() async {
    try {
      final eventProvider = context.read<EventProvider>();
      final stream = eventProvider.getEventById(_event.eventId);
      
      await for (final update in stream) {
        if (update != null && mounted) {
          setState(() {
            _event = update;
            _enableReminders = _event.enableAutoReminders;
            _selectedFrequency = _event.reminderFrequency;
            _daysController.text = _event.reminderDaysBefore.toString();
          });
          break;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading reminder data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Reminder Settings',
      actions: [
        _isSavingSettings
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary(context),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            : IconButton(
                onPressed: _saveReminders,
                icon: Icon(
                  Icons.check_rounded,
                  color: AppColors.textPrimary(context),
                  size: 26,
                ),
                tooltip: 'Save Configuration',
              ),
      ],
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppStyles.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReminderToggle(),
                  _buildScheduleSummary(),
                  
                  if (_enableReminders) ...[
                    _buildSectionHeader('Schedule Frequency', icon: Icons.repeat),
                    _buildFrequencySelector(),
                    
                    if (_selectedFrequency != 'custom') ...[
                      _buildSectionHeader('Parameters', icon: Icons.settings_outlined),
                      _buildSettingsDetail(),
                    ],
                    
                    if (_selectedFrequency == 'custom') ...[
                      _buildSectionHeader('One-time Alerts', icon: Icons.calendar_today_outlined),
                      _buildCustomDatesSection(),
                    ],
                    
                    _buildSectionHeader('Advanced Settings', icon: Icons.tune),
                    _buildAdvancedFeatures(),
                  ],
                  
                  
                  _buildSectionHeader('Manual Reminder', icon: Icons.campaign_outlined),
                  _buildCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Need to send a reminder immediately? Trigger a manual push notification to all participants with unpaid contributions.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _sendRealReminder,
                          icon: Icon(Icons.send_rounded, color: AppColors.primary(context)),
                          label: Text('Send Reminders Now', style: TextStyle(color: AppColors.primary(context), fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primary(context).withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}







