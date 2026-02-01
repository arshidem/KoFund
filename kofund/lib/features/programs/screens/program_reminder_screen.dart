import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:kofund/features/programs/models/program_model.dart';
import 'package:kofund/core/services/reminder_service.dart';

class ProgramRemindersScreen extends StatefulWidget {
  final ProgramModel program;

  const ProgramRemindersScreen({Key? key, required this.program}) : super(key: key);

  @override
  State<ProgramRemindersScreen> createState() => _ProgramRemindersScreenState();
}

class _ProgramRemindersScreenState extends State<ProgramRemindersScreen> {
  late ProgramModel _program;
  final TextEditingController _daysController = TextEditingController();
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

  // ✅ ONLY ONE _sendTestReminder function (using service)
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
          title: Text('Send Test Reminder'),
          content: Text('This will test the reminder system for participants with unpaid contributions. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Send Test', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      
      if (shouldSend != true) {
        _isSendingReminder = false;
        return;
      }
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Sending test reminder...'),
              ],
            ),
          ),
        ),
      );
      
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

  // ✅ ONLY ONE _sendRealReminder function (using service)
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
          title: const Text('Send Real Reminder?'),
          content: const Text('This will send actual push notifications to all participants with unpaid contributions. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Send Real Reminder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      
      if (confirm != true) {
        _isSendingReminder = false;
        return;
      }
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Sending real reminders...'),
              ],
            ),
          ),
        ),
      );
      
      final result = await _reminderService.sendProgramContributionReminders(
        communityId: _program.communityId,
        programId: _program.programId,
        sendTest: false,
      );
      
      if (mounted) Navigator.pop(context); // Close loading
      
      if (result['success'] == true) {
        final remindersSent = result['remindersSent'] ?? 0;
        
        String message = '✅ Real reminders sent successfully';
        if (remindersSent > 0) {
          message += ' to $remindersSent participants';
        }
        
        SnackbarHelper.showSuccess(context, message);
        
        // Refresh data
        await _loadReminderData();
        
        // Show detailed results
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

  // Keep all your UI builder methods (they're fine)
  Widget _buildReminderToggle() {
    return Card(
      child: SwitchListTile(
        title: Text(
          'Enable Contribution Reminders',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        subtitle: Text(
          _enableReminders 
            ? 'Reminders are active for this program'
            : 'Turn on to send reminder notifications',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        value: _enableReminders,
        onChanged: (value) {
          setState(() {
            _enableReminders = value;
          });
        },
        secondary: Icon(
          Icons.notifications,
          color: _enableReminders ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildReminderSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reminder Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedFrequency,
              decoration: InputDecoration(
                labelText: 'Reminder Frequency',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Dates')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedFrequency = value!;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Days Before Due Date',
                suffixText: 'days',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Validate input
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstPaymentDate() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First Payment Due Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text(
                _program.firstPaymentDueDate != null
                  ? DateFormat('MMM dd, yyyy').format(_program.firstPaymentDueDate!)
                  : 'Not set',
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: _pickFirstPaymentDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddReminderDate() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Specific Reminder Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            
            ListTile(
              leading: Icon(Icons.add_alert),
              title: Text(
                _selectedDate != null
                  ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                  : 'Select a date',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: _pickReminderDate,
                  ),
                  if (_selectedDate != null)
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: _addReminderDate,
                      color: Colors.green,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderDatesList() {
    if (_program.contributionReminderDates.isEmpty) {
      return Container();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scheduled Reminders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                TextButton(
                  onPressed: _clearAllReminders,
                  child: Text(
                    'Clear All',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _program.contributionReminderDates.length,
              itemBuilder: (context, index) {
                final date = _program.contributionReminderDates[index];
                return ListTile(
                  leading: Icon(Icons.notifications, color: Colors.orange),
                  title: Text(DateFormat('MMM dd, yyyy').format(date)),
                  subtitle: Text('${date.difference(DateTime.now()).inDays} days from now'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeReminderDate(date),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveReminders,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.primary(context),
        ),
        child: Text(
          'Save Reminder Settings',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _pickFirstPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _program.firstPaymentDueDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        _program = _program.copyWith(firstPaymentDueDate: picked);
      });
    }
  }

  Future<void> _pickReminderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(Duration(days: 7)),
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
        title: Text('Clear All Reminders?'),
        content: Text('Are you sure you want to remove all scheduled reminder dates?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _program = _program.copyWith(contributionReminderDates: []);
              });
              SnackbarHelper.showSuccess(context, 'All reminders cleared');
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveReminders() async {
    try {
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
      
      SnackbarHelper.showSuccess(context, 'Reminder settings saved successfully');
      Navigator.pop(context);
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to save: $e');
    }
  }

  // ✅ Keep these helper methods
  void _showReminderResults(Map<String, dynamic> data) {
    final isTest = data['isTest'] ?? false;
    final success = data['success'] ?? false;
    final message = data['message'] ?? 'Completed';
    
    if (!success) {
      SnackbarHelper.showError(context, '❌ Failed: $message');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.green),
            SizedBox(width: 10),
            Text(isTest ? 'Test Results' : 'Reminder Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✅ $message', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              
              if (data['programResults'] != null && (data['programResults'] as List).isNotEmpty)
                ..._buildProgramResults(data['programResults'] as List),
              
              Divider(),
              
              _buildResultRow('Reminders Sent', '${data['remindersSent'] ?? 0}'),
              _buildResultRow('Notifications Created', '${data['notificationsCreated'] ?? 0}'),
              _buildResultRow('Programs Processed', '${data['programsProcessed'] ?? 0}'),
              
              SizedBox(height: 8),
              Text(
                isTest ? '⚠️ TEST MODE - No actual notifications sent' : '✅ Real reminders sent',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isTest ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProgramResults(List programResults) {
    return [
      Text('Program Details:', style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      for (final result in programResults.cast<Map<String, dynamic>>())
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋 ${result['programName']}', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Participants needing reminders: ${result['participantsNeedingReminders'] ?? 0}'),
                  Text('• Notifications created: ${result['notificationsCreated'] ?? 0}'),
                  Text('• Push notifications sent: ${result['pushNotificationsSent'] ?? 0}'),
                ],
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
    ];
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Reminders - ${_program.title}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'test') {
                _sendTestReminder();
              } else if (value == 'real') {
                _sendRealReminder();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'test',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Send Test Reminder'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'real',
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Send Real Reminder'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReminderToggle(),
            
            if (_enableReminders) ...[
              const SizedBox(height: 20),
              _buildReminderSettings(),
              const SizedBox(height: 20),
              _buildFirstPaymentDate(),
              const SizedBox(height: 20),
              _buildAddReminderDate(),
              const SizedBox(height: 20),
              _buildReminderDatesList(),
              const SizedBox(height: 20),
              _buildSaveButton(),
            ],
          ],
        ),
      ),
    );
  }
}

