import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/features/events/constants/event_Types.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';
import 'package:kofund/core/services/network_service.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _contributionController = TextEditingController(text: '');
  final TextEditingController _totalAmountController = TextEditingController(text: '');
  final TextEditingController _maxParticipantsController = TextEditingController(text: '50');
  
  // Add FocusNodes
  final FocusNode _contributionFocusNode = FocusNode();
  final FocusNode _totalAmountFocusNode = FocusNode();
  final FocusNode _participantsFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 10));
  String? _dateError;
  String _participantType = 'fixed';
  String? _eventType;
  bool _isLoading = false;
  bool _isMonthlyPayment = false;
  bool _sendNotification = true; // ✅ NEW: Control notification sending
  String? _eventTypeError;

  // Track which field was last edited by user
  String _lastEditedField = 'none';
  bool _isUpdating = false; // P recursive updates

  void _scrollToFirstError() {
    final context = _formKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Add listeners for auto-calculation
    _contributionController.addListener(_onContributionChanged);
    _totalAmountController.addListener(_onTotalAamountChanged);
    _maxParticipantsController.addListener(_onParticipantsChanged);
    
    // Set initial values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maxParticipantsController.text = '50';
      _recalculateFromContribution();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contributionController.removeListener(_onContributionChanged);
    _totalAmountController.removeListener(_onTotalAamountChanged);
    _maxParticipantsController.removeListener(_onParticipantsChanged);
    _contributionController.dispose();
    _totalAmountController.dispose();
    _maxParticipantsController.dispose();
    
    // Dispose FocusNodes
    _contributionFocusNode.dispose();
    _totalAmountFocusNode.dispose();
    _participantsFocusNode.dispose();
    
    super.dispose();
  }

void _onContributionChanged() {
  // ✅ Skip auto-calculation for monthly payment events
  if (_participantType != 'fixed' || _isMonthlyPayment || _isUpdating) return;
  
  if (_contributionController.text.isNotEmpty && 
      _contributionFocusNode.hasFocus) {
    _lastEditedField = 'contribution';
    _recalculateFromContribution();
  }
}

void _onTotalAamountChanged() {
  // ✅ Skip auto-calculation for monthly payment events
  if (_participantType != 'fixed' || _isMonthlyPayment || _isUpdating) return;
  
  if (_totalAmountController.text.isNotEmpty && 
      _totalAmountFocusNode.hasFocus) {
    _lastEditedField = 'total';
    _recalculateFromTotal();
  }
}

void _onParticipantsChanged() {
  // ✅ Skip auto-calculation for monthly payment events
  if (_participantType != 'fixed' || _isMonthlyPayment || _isUpdating) return;
  
  if (_maxParticipantsController.text.isNotEmpty && 
      _participantsFocusNode.hasFocus) {
    _lastEditedField = 'participants';
    _recalculateFromParticipants();
  }
}

  void _recalculateFromContribution() {
    if (_isUpdating) return;
    _isUpdating = true;
    
    final contributionText = _contributionController.text;
    final participantsText = _maxParticipantsController.text;
    
    final contribution = double.tryParse(contributionText);
    final participants = int.tryParse(participantsText);
    
    if (contribution != null && participants != null && contribution > 0 && participants > 0) {
      final totalAmount = contribution * participants;
      
      _totalAmountController.removeListener(_onTotalAamountChanged);
      _totalAmountController.text = totalAmount.toStringAsFixed(0);
      _totalAmountController.addListener(_onTotalAamountChanged);
    }
    
    _isUpdating = false;
  }

  void _recalculateFromTotal() {
    if (_isUpdating) return;
    _isUpdating = true;
    
    final totalText = _totalAmountController.text;
    final participantsText = _maxParticipantsController.text;
    
    final total = double.tryParse(totalText);
    final participants = int.tryParse(participantsText);
    
    if (total != null && participants != null && total > 0 && participants > 0) {
      final contribution = total / participants;
      final roundedContribution = (contribution * 100).round() / 100;
      
      _contributionController.removeListener(_onContributionChanged);
      _contributionController.text = roundedContribution.toStringAsFixed(
        roundedContribution.truncateToDouble() == roundedContribution ? 0 : 2
      );
      _contributionController.addListener(_onContributionChanged);
    }
    
    _isUpdating = false;
  }

  void _recalculateFromParticipants() {
    if (_isUpdating) return;
    
    if (_lastEditedField == 'contribution') {
      _recalculateFromContribution();
    } else if (_lastEditedField == 'total') {
      _recalculateFromTotal();
    } else {
      _recalculateFromContribution();
    }
  }

 void _handleParticipantTeventTypeChange(String newTeventType) {
  setState(() {
    _participantType = newTeventType;
    _lastEditedField = 'none';
  });

  // ✅ Only perform calculations for non-monthly fixed type events
  if (newTeventType == 'fixed' && !_isMonthlyPayment) {
    _isUpdating = true;

    final hasContribution = _contributionController.text.isNotEmpty &&
        double.tryParse(_contributionController.text) != null;
    final hasTotalAamount = _totalAmountController.text.isNotEmpty &&
        double.tryParse(_totalAmountController.text) != null;
    final hasParticipants = _maxParticipantsController.text.isNotEmpty &&
        int.tryParse(_maxParticipantsController.text) != null;

    // Case 1: We have total amount and participants -> calculate contribution
    if (hasTotalAamount && hasParticipants) {
      final total = double.parse(_totalAmountController.text);
      final participants = int.parse(_maxParticipantsController.text);
      if (total > 0 && participants > 0) {
        final contribution = total / participants;
        final roundedContribution = (contribution * 100).round() / 100;
        _contributionController.removeListener(_onContributionChanged);
        _contributionController.text = roundedContribution.toStringAsFixed(
          roundedContribution.truncateToDouble() == roundedContribution ? 0 : 2
        );
        _contributionController.addListener(_onContributionChanged);
      }
    }
    // Case 2: We have contribution and participants -> calculate total
    else if (hasContribution && hasParticipants) {
      final contribution = double.parse(_contributionController.text);
      final participants = int.parse(_maxParticipantsController.text);
      if (contribution > 0 && participants > 0) {
        final totalAmount = contribution * participants;
        _totalAmountController.removeListener(_onTotalAamountChanged);
        _totalAmountController.text = totalAmount.toStringAsFixed(0);
        _totalAmountController.addListener(_onTotalAamountChanged);
      }
    }
    // Case 3-5: Keep as is or leave empty

    _isUpdating = false;
  }
}

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary(context),
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary(context),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.card(context),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    FocusNode? focusNode,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int maxLength = 50,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    bool isRequired = false,
    bool showCharacterCounter = false, // Only true for title field
    String? Function(String?)? validator,
  }) {
    final List<TextInputFormatter> formatters = [
      if (inputFormatters != null) ...inputFormatters,
      LengthLimitingTextInputFormatter(maxLength),
    ];

    // Only add asterisk to label if isRequired is true and label does not already have one
    String displayLabel = label;
    if (isRequired && !label.trim().endsWith('*')) {
      displayLabel = '$label *';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          inputFormatters: formatters,
          validator: validator,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            labelText: displayLabel,
            labelStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
            floatingLabelStyle: TextStyle(
              color: AppColors.primary(context),
              fontWeight: FontWeight.w600,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: maxLines > 1 ? 13 : 14,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary(context),
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: maxLines == 1 ? 18 : 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              borderSide: BorderSide(
                color: AppColors.primary(context),
                width: 2,
              ),
            ),
            errorText: errorText,
            errorStyle: const TextStyle(
              fontSize: 12,
              height: 1.2,
            ),
            counterText: '', // Always hide default counter
          ),
        ),
        // Custom character counter - ONLY shown for title field
        if (showCharacterCounter)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final currentLength = value.text.length;
                  final remaining = maxLength - currentLength;
                  final hasText = currentLength > 0;
                  final isFocused = focusNode?.hasFocus ?? false;
                  if (isFocused || hasText) {
                    return Text(
                      '$currentLength/$maxLength',
                      style: TextStyle(
                        fontSize: 12,
                        color: remaining <= 10 
                          ? Colors.orange 
                          : AppColors.textSecondary(context),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _builTeventTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: _eventTypeError != null 
                  ? Colors.red.withValues(alpha: 0.8) 
                  : AppColors.border(context),
              width: _eventTypeError != null ? 1.5 : 1,
            ),
            color: _eventTypeError != null 
                ? Colors.red.withValues(alpha: 0.03) 
                : AppColors.surface(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _eventType,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: _eventTypeError != null 
                    ? Colors.red 
                    : AppColors.textSecondary(context),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              hint: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  'Select event type *',
                  style: TextStyle(
                    color: _eventTypeError != null 
                        ? Colors.red.withValues(alpha: 0.7) 
                        : AppColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ),
              items: EventTypes.allTypes.map((type) {
                return DropdownMenuItem<String?>(
                  value: type,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        child: Center(
                          child: Icon(
                            EventTypes.getIconData(type),
                            color: AppColors.primary(context),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              EventTypes.getDisplayName(type),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              EventTypes.getDescription(type),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _eventType = value;
                  _eventTypeError = null;
                });
              },
            ),
          ),
        ),
        
        if (_eventTypeError != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _eventTypeError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    String? validateDate(DateTime date) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final selectedOnly = DateTime(date.year, date.month, date.day);
      
      if (selectedOnly.isBefore(todayOnly)) {
        return 'Cannot select a past date';
      }
      if (selectedOnly.isAtSameMomentAs(todayOnly)) {
        return 'Event date must be at least 1 day from today';
      }
      return null;
    }

    final currentDateError = validateDate(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            color: AppColors.surface(context),
            border: Border.all(
              color: currentDateError != null 
                  ? Colors.red.withValues(alpha: 0.8) 
                  : AppColors.border(context),
              width: currentDateError != null ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            onTap: () => _selectDate(context),
            leading: Icon(
              Icons.calendar_today,
              color: currentDateError != null 
                  ? Colors.red 
                  : AppColors.primary(context),
              size: 20,
            ),
            title: Text(
              'Event Date *',
              style: TextStyle(
                fontSize: 14,
                color: currentDateError != null 
                    ? Colors.red 
                    : AppColors.textSecondary(context),
              ),
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 15,
                color: currentDateError != null 
                    ? Colors.red.withValues(alpha: 0.8) 
                    : AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.arrow_drop_down,
              color: currentDateError != null 
                  ? Colors.red 
                  : AppColors.textSecondary(context),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        
        if (currentDateError != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  currentDateError,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _create() async {
    setState(() {
      _eventTypeError = null;
    });

    bool hasErrors = false;
    
    _formKey.currentState!.validate();

    if (_eventType == null || _eventType!.isEmpty) {
      setState(() {
        _eventTypeError = 'Please select an event type';
      });
      hasErrors = true;
    }

    if (_titleController.text.isEmpty || _titleController.text.length < 3) {
      hasErrors = true;
    }

    if (_participantType == 'fixed') {
      if (_contributionController.text.isEmpty) {
        hasErrors = true;
      } else {
        final contribution = double.tryParse(_contributionController.text);
        if (contribution == null || contribution <= 0) {
          hasErrors = true;
        }
      }

      if (_maxParticipantsController.text.isEmpty) {
        hasErrors = true;
      } else {
        final participants = int.tryParse(_maxParticipantsController.text);
        if (participants == null || participants <= 0) {
          hasErrors = true;
        }
        if (participants != null && participants > 1000) {
          hasErrors = true;
        }
      }
      
      if (_totalAmountController.text.isNotEmpty) {
        final totalAmount = double.tryParse(_totalAmountController.text);
        if (totalAmount == null || totalAmount <= 0) {
          hasErrors = true;
        }
      }
      
    } else {
      if (_totalAmountController.text.isEmpty) {
        hasErrors = true;
      } else {
        final totalAmount = double.tryParse(_totalAmountController.text);
        if (totalAmount == null || totalAmount <= 0) {
          hasErrors = true;
        }
      }
      
      if (_contributionController.text.isNotEmpty) {
        final contribution = double.tryParse(_contributionController.text);
        if (contribution == null || contribution <= 0) {
          hasErrors = true;
        }
      }
    }

    if (!_isMonthlyPayment) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final selectedOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      
      if (selectedOnly.isBefore(todayOnly) || selectedOnly.isAtSameMomentAs(todayOnly)) {
        hasErrors = true;
      }
    }

    if (hasErrors) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstError();
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AppAuthProvider>();
      final eventProvider = context.read<EventProvider>();

      double? totalAmount;
      
      if (_participantType == 'fixed') {
        if (_totalAmountController.text.isNotEmpty) {
          totalAmount = double.tryParse(_totalAmountController.text);
        } else {
          final contribution = double.parse(_contributionController.text);
          final maxParticipants = int.parse(_maxParticipantsController.text);
          totalAmount = contribution * maxParticipants;
        }
      } else {
        if (_totalAmountController.text.isNotEmpty) {
          totalAmount = double.tryParse(_totalAmountController.text);
        }
      }

      final event = EventModel(
        eventId: '',
        communityId: authProvider.user!.communityId!,
        title: _titleController.text,
        description: _descriptionController.text.trim(),
        eventDate: _isMonthlyPayment ? null : _selectedDate,
        location: _locationController.text.trim(),
        suggestedContribution: _contributionController.text.isNotEmpty 
            ? double.parse(_contributionController.text)
            : null,
 totalAmount: _isMonthlyPayment 
      ? null  // Monthly events don't have a total amount
      : (_totalAmountController.text.isNotEmpty 
          ? double.tryParse(_totalAmountController.text) 
          : null),        maxParticipants: _participantType == 'fixed' 
            ? int.parse(_maxParticipantsController.text)
            : 9999,
        participantType: _participantType,
        status: 'active',
        createdBy: authProvider.user!.uid,
        createdAt: Timestamp.now(),
        currentParticipants: 0,
        eventType: _eventType!,
        isMonthlyPayment: _isMonthlyPayment,
        contributionReminderDates: [],
        enableAutoReminders: false,
        reminderDaysBefore: 7,
        reminderFrequency: 'monthly',
        firstPaymentDueDate: null,
        nextReminderDate: null,
        updatedAt: null,
        lastReminderSent: null,
      );

      await eventProvider.create(event, sendNotification: _sendNotification);
      if (!mounted) return;
      
      Navigator.pop(context);
      
      SnackbarHelper.showSuccess(context, 'Event created successfully!');
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Failed to create event: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Create New Event',
      actions: [
        StatefulBuilder(
          builder: (context, setState) {
            return _isLoading
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.textPrimary(context)),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StreamBuilder<bool>(
                      stream: NetworkService().onConnectionChanged,
                      initialData: true,
                      builder: (context, snapshot) {
                        final bool isOnline = snapshot.data ?? true;
                        return IconButton(
                          icon: isOnline
                              ? Icon(Icons.check,
                                  color: AppColors.textPrimary(context), size: 26)
                              : Icon(Icons.wifi_off,
                                  color: AppColors.textPrimary(context).withValues(alpha: 0.7),
                                  size: 26),
                          tooltip: isOnline ? 'Create Event' : 'Offline - No Connection',
                          onPressed: isOnline ? _create : null,
                        );
                      },
                    ),
                  );
          },
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      // 1. Event Ttitle - ONLY field with character counter
                      _buildInputField(
                        controller: _titleController,
                        label: 'Event Ttitle',
                        icon: Icons.event,
                        hint: 'e.g., Monthly Savings, Trip to Goa, Birthday Fund',
                        isRequired: true,
                        maxLength: 50,
                        showCharacterCounter: true, // Only true here
                        focusNode: FocusNode(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an event title';
                          }
                          if (value.length < 3) {
                            return 'Ttitle must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 2. event type Dropdown
                      _builTeventTypeDropdown(),
                      const SizedBox(height: 12),

                      // 3. Monthly event Toggle
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                          color: AppColors.surface(context),
                          border: Border.all(
                            color: AppColors.border(context),
                          ),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Monthly Contribution',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          subtitle: Text(
                            'Enable for recurring monthly contribution events',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          value: _isMonthlyPayment,
                          // In the SwitchListTile onChanged:
onChanged: (value) {
  setState(() {
    _isMonthlyPayment = value;
    // ✅ Clear total amount field when monthly is enabled
    if (value) {
      _totalAmountController.removeListener(_onTotalAamountChanged);
      _totalAmountController.clear();
      _totalAmountController.addListener(_onTotalAamountChanged);
      
      // Also clear any auto-calculation state
      _lastEditedField = 'none';
    }
  });
},
                          activeThumbColor: AppColors.primary(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 🆕 3.1 Notify Community Toggle
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                          color: AppColors.surface(context),
                          border: Border.all(
                            color: AppColors.border(context),
                          ),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Notify Community',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          subtitle: Text(
                            'Send a push notification to all members',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          value: _sendNotification,
                          onChanged: (value) {
                            setState(() {
                              _sendNotification = value;
                            });
                          },
                          activeThumbColor: AppColors.primary(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Suggested Contribution
                      _buildInputField(
                        controller: _contributionController,
                        label: (_participantType == 'fixed' || _isMonthlyPayment)
                            ? 'Suggested Contribution'
                            : 'Suggested Contribution (Optional)',
                        icon: Icons.currency_rupee,
                        hint: (_participantType == 'fixed' || _isMonthlyPayment)
                            ? 'e.g., 500, 1000, 2000'
                            : 'e.g., 500, 1000, 2000 (optional)',
                        maxLength: 10,
                        showCharacterCounter: false, // No counter
                        focusNode: _contributionFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        isRequired: _participantType == 'fixed' || _isMonthlyPayment,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (_isMonthlyPayment || _participantType == 'fixed') {
                            if (value == null || value.isEmpty) {
                              return 'Please enter contribution amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                          } else {
                            if (value != null && value.isNotEmpty) {
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Please enter a valid amount';
                              }
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 5. Total event Amount - NOW EDITABLE for fixed type
                      if (!_isMonthlyPayment)
                        _buildInputField(
                          controller: _totalAmountController,
                          label: _participantType == 'unlimited' ? 'Total event Amount *' : 'Total event Amount',
                          icon: Icons.currency_rupee,
                          hint: _participantType == 'fixed'
                              ? 'e.g., 50000, 100000 (auto-calculates contribution)'
                              : 'e.g., 50000, 100000 (required)',
                          maxLength: 10,
                          showCharacterCounter: false, // No counter
                          focusNode: _totalAmountFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          isRequired: _participantType == 'unlimited',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (_participantType == 'unlimited') {
                              if (value == null || value.isEmpty) {
                                return 'Total event amount is required for unlimited participants';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Please enter a valid amount';
                              }
                            }
                            return null;
                          },
                        ),

                      if (!_isMonthlyPayment) const SizedBox(height: 12),

                      // 6. event Date
                      if (!_isMonthlyPayment) ...[
                        _buildDatePickerField(),
                      ],

                      // 7. Participant type Selection
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                          color: AppColors.surface(context),
                          border: Border.all(
                            color: AppColors.border(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'Participant type *',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(
                                      'Fixed Number',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Set maximum participants',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                    value: 'fixed',
                                    groupValue: _participantType,
                                    activeColor: AppColors.primary(context),
                                    onChanged: (value) => _handleParticipantTeventTypeChange(value!),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(
                                      'Unlimited',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'No participant limit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                    value: 'unlimited',
                                    groupValue: _participantType,
                                    activeColor: AppColors.primary(context),
                                    onChanged: (value) => _handleParticipantTeventTypeChange(value!),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 8. Maximum Participants
                      if (_participantType == 'fixed')
                        _buildInputField(
                          controller: _maxParticipantsController,
                          focusNode: _participantsFocusNode,
                          label: 'Maximum Participants',
                          icon: Icons.people,
                          hint: 'e.g., 20, 50, 100',
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          showCharacterCounter: false, // No counter
                          isRequired: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (_participantType == 'fixed') {
                              if (value == null || value.isEmpty) {
                                return 'Please enter maximum participants';
                              }
                              final count = int.tryParse(value);
                              if (count == null || count <= 0) {
                                return 'Please enter a valid number';
                              }
                              if (count > 1000) {
                                return 'Maximum participants cannot exceed 1000';
                              }
                            }
                            return null;
                          },
                        ),

                      const SizedBox(height: 20),

                      // ...existing code...
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}





