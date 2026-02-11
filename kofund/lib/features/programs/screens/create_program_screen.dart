import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import '../providers/program_provider.dart';
import '../models/program_model.dart';
import 'package:kofund/core/services/network_service.dart';

class CreateProgramScreen extends StatefulWidget {
  const CreateProgramScreen({super.key});

  @override
  State<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

// Add FocusNode to your state class
class _CreateProgramScreenState extends State<CreateProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _contributionController = TextEditingController(text: '');
  final TextEditingController _totalProgramAmountController = TextEditingController(text: '');
  final TextEditingController _maxParticipantsController = TextEditingController(text: '50');
  
  // Add FocusNodes
  final FocusNode _contributionFocusNode = FocusNode();
  final FocusNode _totalAmountFocusNode = FocusNode();
  final FocusNode _participantsFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 10));
  String? _dateError;
  String _participantType = 'fixed';
  String? _programType;
  bool _isLoading = false;
  bool _isMonthlyPaymentProgram = false;
  String? _programTypeError;

  // Track which field was last edited by user
  String _lastEditedField = 'none'; // 'contribution', 'total', 'participants', 'none'

  @override
  void initState() {
    super.initState();
    
    // Add listeners for auto-calculation
    _contributionController.addListener(_onContributionChanged);
    _totalProgramAmountController.addListener(_onTotalAmountChanged);
    _maxParticipantsController.addListener(_onParticipantsChanged);
    
    // Set initial values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maxParticipantsController.text = '50';
      _recalculateFromContribution();
    });
  }
// Add this method to your _CreateProgramScreenState class
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contributionController.removeListener(_onContributionChanged);
    _totalProgramAmountController.removeListener(_onTotalAmountChanged);
    _maxParticipantsController.removeListener(_onParticipantsChanged);
    _contributionController.dispose();
    _totalProgramAmountController.dispose();
    _maxParticipantsController.dispose();
    
    // Dispose FocusNodes
    _contributionFocusNode.dispose();
    _totalAmountFocusNode.dispose();
    _participantsFocusNode.dispose();
    
    super.dispose();
  }

  void _onContributionChanged() {
    if (_participantType != 'fixed') return;

    // Only recalculate if the field has focus (user is directly editing)
    if (_contributionFocusNode.hasFocus && _contributionController.text.isNotEmpty) {
      _lastEditedField = 'contribution';
      _recalculateFromContribution();
    }
  }

  void _onTotalAmountChanged() {
    if (_participantType != 'fixed') return;

    // Only recalculate if the field has focus (user is directly editing)
    if (_totalAmountFocusNode.hasFocus && _totalProgramAmountController.text.isNotEmpty) {
      _lastEditedField = 'total';
      _recalculateFromTotal();
    }
  }

  void _onParticipantsChanged() {
    if (_participantType != 'fixed') return;

    // Only recalculate if the field has focus (user is directly editing) and has content
    if (_participantsFocusNode.hasFocus && _maxParticipantsController.text.isNotEmpty) {
      _lastEditedField = 'participants';
      _recalculateFromParticipants();
    }
  }

  void _recalculateFromContribution() {
    final contributionText = _contributionController.text;
    final participantsText = _maxParticipantsController.text;
    
    final contribution = double.tryParse(contributionText);
    final participants = int.tryParse(participantsText);
    
    if (contribution != null && participants != null && contribution > 0 && participants > 0) {
      final totalAmount = contribution * participants;
      
      // Update total without triggering its listener
      _totalProgramAmountController.removeListener(_onTotalAmountChanged);
      _totalProgramAmountController.text = totalAmount.toStringAsFixed(0);
      _totalProgramAmountController.addListener(_onTotalAmountChanged);
    }
  }

  void _recalculateFromTotal() {
    final totalText = _totalProgramAmountController.text;
    final participantsText = _maxParticipantsController.text;
    
    final total = double.tryParse(totalText);
    final participants = int.tryParse(participantsText);
    
    if (total != null && participants != null && total > 0 && participants > 0) {
      final contribution = total / participants;
      // Round to nearest rupee
      final roundedContribution = (contribution * 100).round() / 100;
      
      // Update contribution without triggering its listener
      _contributionController.removeListener(_onContributionChanged);
      _contributionController.text = roundedContribution.toStringAsFixed(
        roundedContribution.truncateToDouble() == roundedContribution ? 0 : 2
      );
      _contributionController.addListener(_onContributionChanged);
    }
  }

  void _recalculateFromParticipants() {
    final lastEdited = _lastEditedField;
    final participantsText = _maxParticipantsController.text;
    final participants = int.tryParse(participantsText);

    if (participants == null || participants <= 0) return;

    if (lastEdited == 'contribution') {
      // Scenario 3a: User changed Participants while Contribution was last edited
      // Keep Contribution, Recalculate Total
      _recalculateFromContribution();
    } else if (lastEdited == 'total') {
      // Scenario 3c: User changed Participants while Total was last edited
      // Keep Total, Recalculate Contribution
      _recalculateFromTotal();
    } else {
      // Default: Keep Contribution and recalculate Total
      _recalculateFromContribution();
    }
  }

  void _handleParticipantTypeChange(String value) {
    setState(() {
      _participantType = value;
      _lastEditedField = 'none';
      
      if (value == 'fixed') {
        // Set default participants if empty
        if (_maxParticipantsController.text.isEmpty) {
          _maxParticipantsController.text = '50';
        }
        // Recalculate if both fields have values
        _recalculateFromContribution();
      } else {
        // Clear total amount for unlimited
        _totalProgramAmountController.removeListener(_onTotalAmountChanged);
        _totalProgramAmountController.clear();
        _totalProgramAmountController.addListener(_onTotalAmountChanged);
      }
    });
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
            dialogBackgroundColor: AppColors.card(context),
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
  FocusNode? focusNode, // Add this parameter
  bool obscureText = false,
  bool showObscureToggle = false,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  int maxLength = 50,
  List<TextInputFormatter>? inputFormatters,
  String? errorText,
  bool isRequired = false,
  bool showCharacterCounter = false,
  bool readOnly = false,
  String? Function(String?)? validator,
}) {
  final List<TextInputFormatter> formatters = [
    if (inputFormatters != null) ...inputFormatters,
    if (!readOnly) LengthLimitingTextInputFormatter(maxLength),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        controller: controller,
        focusNode: focusNode, // Add focus node
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: readOnly ? null : maxLength,
        maxLengthEnforcement: readOnly ? MaxLengthEnforcement.none : MaxLengthEnforcement.enforced,
        inputFormatters: formatters,
        readOnly: readOnly,
        validator: validator,
        style: TextStyle(
          color: readOnly ? AppColors.textSecondary(context) : AppColors.textPrimary(context),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
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
            color: readOnly ? AppColors.textSecondary(context) : AppColors.primary(context),
            size: 20,
          ),
          filled: true,
          fillColor: readOnly ? AppColors.surface(context).withValues(alpha: 0.7) : AppColors.surface(context),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: maxLines == 1 ? 18 : 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
          counterText: readOnly ? '' : null,
        ),
      ),
      
      if (showCharacterCounter && !readOnly)
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
                
                final bool isFocused = focusNode?.hasFocus ?? false;
                
                if (isFocused || hasText) {
                  return Text(
                    '$currentLength/$maxLength',
                    style: TextStyle(
                      fontSize: 13,
                      color: remaining <= 10 
                        ? Colors.orange 
                        : AppColors.textSecondary(context),
                      fontWeight: remaining <= 10 ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildProgramTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _programTypeError != null 
                  ? Colors.red.withValues(alpha: 0.8) 
                  : AppColors.border(context),
              width: _programTypeError != null ? 1.5 : 1,
            ),
            color: _programTypeError != null 
                ? Colors.red.withValues(alpha: 0.03) 
                : AppColors.surface(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _programType,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: _programTypeError != null 
                    ? Colors.red 
                    : AppColors.textSecondary(context),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              hint: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  'Select program type *',
                  style: TextStyle(
                    color: _programTypeError != null 
                        ? Colors.red.withValues(alpha: 0.7) 
                        : AppColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ),
              items: ProgramTypes.allTypes.map((type) {
                return DropdownMenuItem<String?>(
                  value: type,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            ProgramTypes.getIconData(type),
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
                              ProgramTypes.getDisplayName(type),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ProgramTypes.getDescription(type),
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
                  _programType = value;
                  _programTypeError = null;
                });
              },
            ),
          ),
        ),
        
        if (_programTypeError != null)
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
                  _programTypeError!,
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
    String? _validateDate(DateTime date) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final selectedOnly = DateTime(date.year, date.month, date.day);
      
      if (selectedOnly.isBefore(todayOnly)) {
        return 'Cannot select a past date';
      }
      if (selectedOnly.isAtSameMomentAs(todayOnly)) {
        return 'Program date must be at least 1 day from today';
      }
      return null;
    }

    final currentDateError = _validateDate(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
              'Program Date *',
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

Future<void> _createProgram() async {
  setState(() {
    _programTypeError = null;
  });

  bool hasErrors = false;
  
  _formKey.currentState!.validate();

  if (_programType == null || _programType!.isEmpty) {
    setState(() {
      _programTypeError = 'Please select a program type';
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
    
    // Ensure total is calculated
    _recalculateFromContribution();
    
  } else {
    if (_totalProgramAmountController.text.isEmpty) {
      hasErrors = true;
    } else {
      final totalAmount = double.tryParse(_totalProgramAmountController.text);
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

  if (!_isMonthlyPaymentProgram) {
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
    final programProvider = context.read<ProgramProvider>();

    double? totalProgramAmount;
    
    if (_participantType == 'fixed') {
      final contribution = double.parse(_contributionController.text);
      final maxParticipants = int.parse(_maxParticipantsController.text);
      totalProgramAmount = contribution * maxParticipants;
    } else {
      if (_totalProgramAmountController.text.isNotEmpty) {
        totalProgramAmount = double.tryParse(_totalProgramAmountController.text);
      }
    }

    final program = ProgramModel(
      programId: '',
      communityId: authProvider.user!.communityId!,
      title: _titleController.text,
      description: _descriptionController.text.trim(),
      // FIX 1: programDate expects DateTime - pass DateTime directly
      programDate: _isMonthlyPaymentProgram ? DateTime.now() : _selectedDate,
      location: _locationController.text.trim(),
      suggestedContribution: _contributionController.text.isNotEmpty 
          ? double.parse(_contributionController.text)
          : null,
      totalProgramAmount: totalProgramAmount,
      // FIX 2: maxParticipants expects int (non-nullable)
      // For unlimited, set a very high number (9999) since it's non-nullable
      maxParticipants: _participantType == 'fixed' 
          ? int.parse(_maxParticipantsController.text)
          : 9999, // High number for unlimited
      participantType: _participantType,
      status: 'active',
      createdBy: authProvider.user!.uid,
      // FIX 3: createdAt expects Timestamp
      createdAt: Timestamp.now(),
      currentParticipants: 0,
      programType: _programType!,
      isMonthlyPaymentProgram: _isMonthlyPaymentProgram,
      // Optional fields with defaults
      contributionReminderDates: [],
      enableAutoReminders: false,
      reminderDaysBefore: 7,
      reminderFrequency: 'monthly',
      firstPaymentDueDate: null,
      nextReminderDate: null,
      updatedAt: null,
      lastReminderSent: null,
    );

    await programProvider.createProgram(program);
    if (!mounted) return;
    
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Program created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to create program: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

// In the build method, update the Column children order:

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      toolbarHeight: 80,
      title: const Text(
        'Create New Program',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background(context),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient(context),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      automaticallyImplyLeading: true,
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // 1. Program Title
                    _buildInputField(
                      controller: _titleController,
                      label: 'Program Title',
                      icon: Icons.event,
                      hint: 'e.g., Monthly Savings, Trip to Goa, Birthday Fund',
                      isRequired: true,
                      maxLength: 50,
                      showCharacterCounter: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a program title';
                        }
                        if (value.length < 3) {
                          return 'Title must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // 2. Program Type Dropdown
                    _buildProgramTypeDropdown(),
                    const SizedBox(height: 12),

                    // 3. Monthly Program Toggle
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
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
                          'Enable for recurring monthly contribution programs',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        value: _isMonthlyPaymentProgram,
                        onChanged: (value) {
                          setState(() => _isMonthlyPaymentProgram = value);
                        },
                        activeColor: AppColors.primary(context),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Suggested Contribution (MOVED UP)
                    _buildInputField(
                      controller: _contributionController,
                      label: _participantType == 'fixed' 
                          ? 'Suggested Contribution' 
                          : 'Suggested Contribution (Optional)',
                      icon: Icons.currency_rupee,
                      hint: _participantType == 'fixed'
                          ? 'e.g., 500, 1000, 2000'
                          : 'e.g., 500, 1000, 2000 (optional)',
                      showCharacterCounter: true,
                      maxLength: 10,
                      focusNode: _contributionFocusNode, // Add focus node
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      isRequired: _participantType == 'fixed',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (_participantType == 'fixed') {
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

                    // 5. Total Program Amount (MOVED UP - only for non-monthly)
                    // Total Program Amount - Update the readOnly condition and add focus node
if (!_isMonthlyPaymentProgram)
  _buildInputField(
    controller: _totalProgramAmountController,
    label: _participantType == 'fixed'
        ? 'Total Program Amount'
        : 'Total Program Amount *',
    icon: Icons.currency_rupee,
    hint: _participantType == 'fixed'
        ? 'Auto-calculated or enter manually to set contribution'
        : 'e.g., 50000, 100000 (required)',
    maxLength: 10,
    showCharacterCounter: true,
    focusNode: _totalAmountFocusNode, // Add focus node
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    readOnly: false, // Total is now editable in both fixed and unlimited modes
    inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
    validator: (value) {
      if (_participantType == 'unlimited') {
        if (value == null || value.isEmpty) {
          return 'Total program amount is required for unlimited participants';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount';
        }
      }
      return null;
    },
  ),

                    if (!_isMonthlyPaymentProgram) const SizedBox(height: 12),

                    // 6. Program Date (Only show for non-monthly programs)
                    if (!_isMonthlyPaymentProgram) ...[
                      _buildDatePickerField(),
                    ],

                    // 7. Participant Type Selection
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
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
                              'Participant Type *',
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
                                  onChanged: (value) => _handleParticipantTypeChange(value!),
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
                                  onChanged: (value) => _handleParticipantTypeChange(value!),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 8. Maximum Participants (only for fixed type)
                    if (_participantType == 'fixed')
                      _buildInputField(
                        controller: _maxParticipantsController,
                        focusNode: _participantsFocusNode, // Add focus node
                        label: 'Maximum Participants',
                        icon: Icons.people,
                        hint: 'e.g., 20, 50, 100',
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        showCharacterCounter: true,
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

                    // 9. Create Button
                    FutureBuilder<bool>(
                      future: NetworkService().isConnected,
                      builder: (context, snapshot) {
                        final bool isOnline = snapshot.data ?? true;
                        
                        return StreamBuilder<bool>(
                          stream: NetworkService().onConnectionChanged,
                          builder: (context, streamSnapshot) {
                            final bool currentIsOnline = streamSnapshot.data ?? isOnline;
                            final bool isDisabled = _isLoading || !currentIsOnline;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isDisabled ? null : _createProgram,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary(context),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          AppColors.primary(context).withValues(alpha: 0.5),
                                      disabledForegroundColor: Colors.white70,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                currentIsOnline ? Icons.add_circle_outline : Icons.wifi_off,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                currentIsOnline ? 'Create Program' : 'Offline',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                
                                if (!currentIsOnline)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: Colors.redAccent,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Internet connection required',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}