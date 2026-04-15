import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:kofund/features/programs/models/program_model.dart';
import 'package:kofund/core/services/reminder_service.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/widgets/custom_button.dart';

class ProgramRemindersScreen extends StatefulWidget {
  final ProgramModel program;

  const ProgramRemindersScreen({super.key, required this.program});

  @override
  State<ProgramRemindersScreen> createState() => _ProgramRemindersScreenState();
}

class _ProgramRemindersScreenState extends State<ProgramRemindersScreen> {
  late ProgramModel _program;
  final TextEditingController _daysController = TextEditingController();
  final FocusNode _daysFocus = FocusNode();
  String _selectedFrequency = 'monthly';
  DateTime? _selectedDate;
  bool _enableReminders = false;
  bool _isSendingReminder = false;
  late ReminderService _reminderService;

  @override
  void initState() {
    super.initState();
    _program = widget.program;
    _enableReminders = _program.enableAutoReminders;
    _selectedFrequency = _program.reminderFrequency;
    _daysController.text = _program.reminderDaysBefore.toString();
    _reminderService = ReminderService();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _daysFocus.dispose();
    super.dispose();
  }

  Future<void> _sendTestReminder() async {
    if (_isSendingReminder) {
      SnackbarHelper.showInfo(context, 'Please wait, reminder is already being sent');
      return;
    }
    
    _isSendingReminder = true;
    
    try {
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
          title: const Text('Send Test Reminder'),
          content: const Text('This will test the reminder system for participants with unpaid contributions. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary(context)),
              child: const Text('Send Test', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      
      if (shouldSend != true) {
        _isSendingReminder = false;
        return;
      }
      
      _showLoadingDialog('Sending test reminder...');
      
      final result = await _reminderService.sendProgramContributionReminders(
        communityId: _program.communityId,
        programId: _program.programId,
        sendTest: true,
      );
      
      if (mounted) Navigator.pop(context); // Close loading
      
      if (result['success'] == true) {
        _showReminderResults(result);
      } else {
        SnackbarHelper.showError(context, 'Failed: ${result['message']}');
      }
      
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        SnackbarHelper.showError(context, 'Failed to send test: $e');
      }
    } finally {
      _isSendingReminder = false;
    }
  }

  Future<void> _sendRealReminder() async {
    if (_isSendingReminder) {
      SnackbarHelper.showInfo(context, 'Please wait, reminder is already being sent');
      return;
    }
    
    _isSendingReminder = true;
    
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
          title: const Text('Send Real Reminder?'),
          content: const Text('This will send actual push notifications to all participants with unpaid contributions. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error(context)),
              child: const Text('Send Real', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      
      if (confirm != true) {
        _isSendingReminder = false;
        return;
      }
      
      _showLoadingDialog('Sending real reminders...');
      
      final result = await _reminderService.sendProgramContributionReminders(
        communityId: _program.communityId,
        programId: _program.programId,
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
              color: AppColors.textSecondary(context).withOpacity(0.8),
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
        border: Border.all(color: AppColors.border(context).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                color: (_enableReminders ? AppColors.primary(context) : Colors.grey).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _enableReminders ? Icons.notifications_active : Icons.notifications_off,
                color: _enableReminders ? AppColors.primary(context) : Colors.grey,
                size: 24,
              ),
            ),
          ),
          if (_enableReminders && _program.nextReminderDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppDimensions.radiusLarge)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, size: 16, color: AppColors.primary(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next scheduled: ${DateFormat('MMMM dd, yyyy').format(_program.nextReminderDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary(context).withOpacity(0.8),
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
              _buildChoiceChip('daily', 'Daily'),
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
      selectedColor: AppColors.primary(context).withOpacity(0.2),
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

  Widget _buildSettingsDetail() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead Time',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Days before due date to start',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _daysController,
                  focusNode: _daysFocus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    suffixText: 'days',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Initial Payment Date',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The very first due date of this program',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _pickFirstPaymentDate,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: AppColors.primary(context).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month, size: 18, color: AppColors.primary(context)),
                      const SizedBox(width: 8),
                      Text(
                        _program.firstPaymentDueDate != null
                            ? DateFormat('MMM dd, yyyy').format(_program.firstPaymentDueDate!)
                            : 'Set Date',
                        style: TextStyle(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        if (_program.contributionReminderDates.isNotEmpty) ...[
          _buildSectionHeader('Scheduled Reminders', icon: Icons.history),
          _buildCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _program.contributionReminderDates.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border(context).withOpacity(0.5)),
              itemBuilder: (context, index) {
                final date = _program.contributionReminderDates[index];
                final isPast = date.isBefore(DateTime.now());
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPast ? Colors.grey : Colors.orange).withOpacity(0.1),
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
                    icon: Icon(Icons.delete_outline, color: AppColors.error(context).withOpacity(0.7)),
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

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.background(context),
      child: CustomButton(
        onPressed: _saveReminders,
        text: 'Save Configuration',
      ),
    );
  }

  Future<void> _pickFirstPaymentDate() async {
    HapticHelper.selection();
    final picked = await showDatePicker(
      context: context,
      initialDate: _program.firstPaymentDueDate ?? DateTime.now().add(const Duration(days: 30)),
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
        _program = _program.copyWith(firstPaymentDueDate: picked);
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
    final newDates = List<DateTime>.from(_program.contributionReminderDates)
      ..add(_selectedDate!)
      ..sort();
    
    setState(() {
      _program = _program.copyWith(contributionReminderDates: newDates);
      _selectedDate = null;
    });
    
    SnackbarHelper.showSuccess(context, 'Reminder date added');
  }

  void _removeReminderDate(DateTime date) {
    final newDates = List<DateTime>.from(_program.contributionReminderDates)
      ..removeWhere((d) => d.isAtSameMomentAs(date));
    
    setState(() {
      _program = _program.copyWith(contributionReminderDates: newDates);
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
                _program = _program.copyWith(contributionReminderDates: []);
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
    try {
      HapticHelper.medium();
      final programProvider = context.read<ProgramProvider>();
      
      final updatedProgram = _program.copyWith(
        enableAutoReminders: _enableReminders,
        reminderDaysBefore: int.tryParse(_daysController.text) ?? 7,
        reminderFrequency: _selectedFrequency,
      );
      
      final nextReminderDate = _enableReminders 
          ? updatedProgram.calculateNextReminderDate()
          : null;
      
      await programProvider.updateProgramReminderSettings(
        programId: _program.programId,
        enableAutoReminders: _enableReminders,
        reminderDaysBefore: int.tryParse(_daysController.text) ?? 7,
        reminderFrequency: _selectedFrequency,
        contributionReminderDates: _program.contributionReminderDates,
        firstPaymentDueDate: _program.firstPaymentDueDate,
        nextReminderDate: nextReminderDate,
      );
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Reminder settings saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to save: $e');
    }
  }

  void _showReminderResults(Map<String, dynamic> data) {
    final isTest = data['isTest'] ?? false;
    final success = data['success'] ?? false;
    final message = data['message'] ?? 'Completed';
    
    if (!success) {
      SnackbarHelper.showError(context, '❌ Failed: $message');
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
                      color: AppColors.success(context).withOpacity(0.1),
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
              _buildResultRow('Batch Size', '${data['programsProcessed'] ?? 0} Programs'),
              const Divider(height: 32),
              if (data['programResults'] != null) ...[
                const Text('Breakdown by Program', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                for (final result in (data['programResults'] as List).cast<Map<String, dynamic>>())
                  _buildProgramResultItem(result),
              ],
              const SizedBox(height: 32),
              if (isTest)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
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

  Widget _buildProgramResultItem(Map<String, dynamic> result) {
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
          Text(result['programName'] ?? 'Untitled Program', style: const TextStyle(fontWeight: FontWeight.bold)),
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
      final programProvider = context.read<ProgramProvider>();
      final stream = programProvider.getProgramById(_program.programId);
      
      await for (final updatedProgram in stream) {
        if (updatedProgram != null && mounted) {
          setState(() {
            _program = updatedProgram;
            _enableReminders = _program.enableAutoReminders;
            _selectedFrequency = _program.reminderFrequency;
            _daysController.text = _program.reminderDaysBefore.toString();
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
      title: 'Reminder Engine',
      actions: [
        Theme(
          data: Theme.of(context).copyWith(
            hoverColor: Colors.white24,
            splashColor: Colors.white24,
          ),
          child: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'test') {
                _sendTestReminder();
              } else if (value == 'real') {
                _sendRealReminder();
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMedium)),
            icon: const Icon(Icons.bolt, color: Colors.white),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'test',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: AppColors.info(context), size: 18),
                    const SizedBox(width: 12),
                    const Text('Dry Run (Test)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'real',
                child: Row(
                  children: [
                    Icon(Icons.rocket_launch, color: AppColors.error(context), size: 18),
                    const SizedBox(width: 12),
                    const Text('Force Execution'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReminderToggle(),
                  
                  if (_enableReminders) ...[
                    _buildSectionHeader('Schedule Frequency', icon: Icons.repeat),
                    _buildFrequencySelector(),
                    
                    _buildSectionHeader('Parameters', icon: Icons.settings_outlined),
                    _buildSettingsDetail(),
                    
                    _buildSectionHeader('One-time Alerts', icon: Icons.calendar_today_outlined),
                    _buildCustomDatesSection(),
                    
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
          if (_enableReminders) _buildSaveButton(),
        ],
      ),
    );
  }
}

