// lib/features/programs/screens/edit_program_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import '../providers/program_provider.dart';
import '../models/program_model.dart';
import 'package:kofund/core/services/network_service.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class EditProgramScreen extends StatefulWidget {
  final ProgramModel program;
  final VoidCallback? onProgramUpdated;

  const EditProgramScreen({
    super.key,
    required this.program,
    this.onProgramUpdated,
  });

  @override
  State<EditProgramScreen> createState() => _EditProgramScreenState();
}

class _EditProgramScreenState extends State<EditProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _suggestedContributionController = TextEditingController();
  final TextEditingController _totalProgramAmountController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();

  // Add FocusNodes for auto-calc
  final FocusNode _contributionFocusNode = FocusNode();
  final FocusNode _totalAmountFocusNode = FocusNode();
  final FocusNode _participantsFocusNode = FocusNode();

  // Track which field was last edited by user
  String _lastEditedField = 'none';
  bool _isUpdating = false;

  DateTime? _selectedDate;
  String? _programType;
  String _participantType = 'fixed';
  bool _isLoading = false;
  bool _isMonthlyPaymentProgram = false;
  String? _programTypeError;
  String? _dateError;

  // Add this method for scrolling to errors
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
    _initializeForm();

    // Add listeners for auto-calculation
    _suggestedContributionController.addListener(_onContributionChanged);
    _totalProgramAmountController.addListener(_onTotalAmountChanged);
    _maxParticipantsController.addListener(_onParticipantsChanged);
  }

  void _initializeForm() {
    final program = widget.program;
    
    _titleController.text = program.title;
    _selectedDate = program.programDate;
    _programType = program.programType;
    _participantType = program.participantType;
    _isMonthlyPaymentProgram = program.isMonthlyPaymentProgram;

    if (program.suggestedContribution != null) {
      _suggestedContributionController.text = program.suggestedContribution!.toStringAsFixed(2);
    }
    
    if (program.totalProgramAmount != null) {
      _totalProgramAmountController.text = program.totalProgramAmount!.toStringAsFixed(2);
    }

    _maxParticipantsController.text = program.maxParticipants.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _suggestedContributionController.removeListener(_onContributionChanged);
    _totalProgramAmountController.removeListener(_onTotalAmountChanged);
    _maxParticipantsController.removeListener(_onParticipantsChanged);
    _suggestedContributionController.dispose();
    _totalProgramAmountController.dispose();
    _maxParticipantsController.dispose();
    _contributionFocusNode.dispose();
    _totalAmountFocusNode.dispose();
    _participantsFocusNode.dispose();
    super.dispose();
  }
  
  void _onContributionChanged() {
    if (_participantType != 'fixed' || _isUpdating) return;
    if (_suggestedContributionController.text.isNotEmpty && _contributionFocusNode.hasFocus) {
      _lastEditedField = 'contribution';
      _recalculateFromContribution();
    }
  }

  void _onTotalAmountChanged() {
    if (_participantType != 'fixed' || _isUpdating) return;
    if (_totalProgramAmountController.text.isNotEmpty && _totalAmountFocusNode.hasFocus) {
      _lastEditedField = 'total';
      _recalculateFromTotal();
    }
  }

  void _onParticipantsChanged() {
    if (_participantType != 'fixed' || _isUpdating) return;
    if (_maxParticipantsController.text.isNotEmpty && _participantsFocusNode.hasFocus) {
      _lastEditedField = 'participants';
      _recalculateFromParticipants();
    }
  }

  void _recalculateFromContribution() {
    if (_isUpdating) return;
    _isUpdating = true;
    final contributionText = _suggestedContributionController.text;
    final participantsText = _maxParticipantsController.text;
    final contribution = double.tryParse(contributionText);
    final participants = int.tryParse(participantsText);
    if (contribution != null && participants != null && contribution > 0 && participants > 0) {
      final totalAmount = contribution * participants;
      _totalProgramAmountController.removeListener(_onTotalAmountChanged);
      _totalProgramAmountController.text = totalAmount.toStringAsFixed(0);
      _totalProgramAmountController.addListener(_onTotalAmountChanged);
    }
    _isUpdating = false;
  }

  void _recalculateFromTotal() {
    if (_isUpdating) return;
    _isUpdating = true;
    final totalText = _totalProgramAmountController.text;
    final participantsText = _maxParticipantsController.text;
    final total = double.tryParse(totalText);
    final participants = int.tryParse(participantsText);
    if (total != null && participants != null && total > 0 && participants > 0) {
      final contribution = total / participants;
      final roundedContribution = (contribution * 100).round() / 100;
      _suggestedContributionController.removeListener(_onContributionChanged);
      _suggestedContributionController.text = roundedContribution.toStringAsFixed(
        roundedContribution.truncateToDouble() == roundedContribution ? 0 : 2
      );
      _suggestedContributionController.addListener(_onContributionChanged);
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

  // 🆕 New method to auto-calculate when switching participant types
  void _handleParticipantTypeChange(String newType) {
    setState(() {
      _participantType = newType;
    });
    
    // Only perform calculations when switching to 'fixed' type
    if (newType == 'fixed') {
      _isUpdating = true;
      
      final hasContribution = _suggestedContributionController.text.isNotEmpty && 
          double.tryParse(_suggestedContributionController.text) != null;
      final hasTotalAmount = _totalProgramAmountController.text.isNotEmpty && 
          double.tryParse(_totalProgramAmountController.text) != null;
      final hasParticipants = _maxParticipantsController.text.isNotEmpty && 
          int.tryParse(_maxParticipantsController.text) != null;
      
      // Case 1: We have total amount and participants -> calculate contribution
      if (hasTotalAmount && hasParticipants) {
        final total = double.parse(_totalProgramAmountController.text);
        final participants = int.parse(_maxParticipantsController.text);
        if (total > 0 && participants > 0) {
          final contribution = total / participants;
          final roundedContribution = (contribution * 100).round() / 100;
          _suggestedContributionController.removeListener(_onContributionChanged);
          _suggestedContributionController.text = roundedContribution.toStringAsFixed(
            roundedContribution.truncateToDouble() == roundedContribution ? 0 : 2
          );
          _suggestedContributionController.addListener(_onContributionChanged);
        }
      }
      // Case 2: We have contribution and participants -> calculate total
      else if (hasContribution && hasParticipants) {
        final contribution = double.parse(_suggestedContributionController.text);
        final participants = int.parse(_maxParticipantsController.text);
        if (contribution > 0 && participants > 0) {
          final totalAmount = contribution * participants;
          _totalProgramAmountController.removeListener(_onTotalAmountChanged);
          _totalProgramAmountController.text = totalAmount.toStringAsFixed(0);
          _totalProgramAmountController.addListener(_onTotalAmountChanged);
        }
      }
      // Case 3: We have only total amount -> keep as is
      // Case 4: We have only contribution -> keep as is
      // Case 5: We have neither -> leave empty
      
      _isUpdating = false;
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
    bool showCharacterCounter = false,
    String? Function(String?)? validator,
  }) {
    final List<TextInputFormatter> formatters = [
      if (inputFormatters != null) ...inputFormatters,
      LengthLimitingTextInputFormatter(maxLength),
    ];

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
            counterText: showCharacterCounter ? '' : null,
          ),
        ),
        
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
                },
              ),
            ),
          ),
      ],
    );
  }

  // 🆕 Validation for Suggested Contribution
  String? _validateSuggestedContribution(String? value) {
    // If monthly payment is enabled, suggested contribution is always required
    if (_isMonthlyPaymentProgram) {
      if (value == null || value.isEmpty) {
        return 'Please enter contribution amount';
      }
      final amount = double.tryParse(value);
      if (amount == null || amount <= 0) {
        return 'Please enter a valid amount';
      }
      return null;
    }

    if (_participantType == 'unlimited') {
      // For unlimited: Not required (can be empty or 0)
      return null;
    }

    // For fixed: Check if there's no total amount entered
    final hasTotalAmount = _totalProgramAmountController.text.isNotEmpty &&
        double.tryParse(_totalProgramAmountController.text) != null &&
        double.parse(_totalProgramAmountController.text) > 0;

    if (value == null || value.isEmpty) {
      // If total amount is also empty, show error
      if (!hasTotalAmount) {
        return 'Either contribution or total amount is required';
      }
      return null; // Total amount exists, so contribution can be empty
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  // 🆕 Validation for Total Program Amount
  String? _validateTotalProgramAmount(String? value) {
    if (_participantType == 'unlimited') {
      // For unlimited: Required
      if (value == null || value.isEmpty) {
        return 'Total program amount is required for unlimited participants';
      }
      final amount = double.tryParse(value);
      if (amount == null) {
        return 'Please enter a valid amount';
      }
      if (amount <= 0) {
        return 'Amount must be greater than 0';
      }
      return null;
    }
    
    // For fixed: Not required if contribution exists
    final hasContribution = _suggestedContributionController.text.isNotEmpty && 
        double.tryParse(_suggestedContributionController.text) != null &&
        double.parse(_suggestedContributionController.text) > 0;
    
    if (value == null || value.isEmpty) {
      // If no contribution entered, show error
      if (!hasContribution) {
        return 'Either total amount or contribution is required';
      }
      return null; // Contribution exists, so total amount can be empty
    }
    
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  // 🆕 Validate participant amount fields based on type
  bool _validateParticipantAmountFields() {
    bool isValid = true;
    
    if (_participantType == 'unlimited') {
      // For unlimited: Total Program Amount is required
      final totalAmountText = _totalProgramAmountController.text;
      final totalAmount = double.tryParse(totalAmountText);
      
      if (totalAmountText.isEmpty || totalAmount == null || totalAmount <= 0) {
        isValid = false;
      }
    } else {
      // For fixed: At least one of Suggested Contribution OR Total Program Amount must be filled
      final hasContribution = _suggestedContributionController.text.isNotEmpty && 
          double.tryParse(_suggestedContributionController.text) != null &&
          double.parse(_suggestedContributionController.text) > 0;
      
      final hasTotalAmount = _totalProgramAmountController.text.isNotEmpty && 
          double.tryParse(_totalProgramAmountController.text) != null &&
          double.parse(_totalProgramAmountController.text) > 0;
      
      if (!hasContribution && !hasTotalAmount) {
        isValid = false;
      }
    }
    
    return isValid;
  }

  // 🆕 Comprehensive validation method
  bool _validateProgram() {
    setState(() {
      _programTypeError = null;
      _dateError = null;
    });

    bool hasErrors = false;
    
    // Force validate all form fields
    _formKey.currentState!.validate();

    // Check program type
    if (_programType == null || _programType!.isEmpty) {
      setState(() {
        _programTypeError = 'Please select a program type';
      });
      hasErrors = true;
    }

    // Check title
    if (_titleController.text.isEmpty || _titleController.text.length < 3) {
      hasErrors = true;
    }


    // Enforce suggested contribution required if monthly payment is enabled
    if (_isMonthlyPaymentProgram) {
      if (_suggestedContributionController.text.isEmpty ||
          double.tryParse(_suggestedContributionController.text) == null ||
          double.parse(_suggestedContributionController.text) <= 0) {
        hasErrors = true;
      }
    } else {
      // Check participant amount fields based on type
      if (!_validateParticipantAmountFields()) {
        hasErrors = true;
      }
    }

    // For fixed participants, check max participants
    if (_participantType == 'fixed') {
      final participantsText = _maxParticipantsController.text;
      final participants = int.tryParse(participantsText);
      if (participantsText.isEmpty || participants == null || participants <= 0) {
        hasErrors = true;
      }
    }

    // For non-monthly programs, validate date
// ✅ Fix: For non-monthly programs, validate date is not null and is valid
if (!_isMonthlyPaymentProgram) {
  if (_selectedDate == null) {
    setState(() {
      _dateError = 'Please select a program date';
    });
    hasErrors = true;
  } else {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selectedOnly = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    
    if (selectedOnly.isBefore(todayOnly) || selectedOnly.isAtSameMomentAs(todayOnly)) {
      setState(() {
        if (selectedOnly.isBefore(todayOnly)) {
          _dateError = 'Cannot select a past date';
        } else {
          _dateError = 'Program date must be at least 1 day from today';
        }
      });
      hasErrors = true;
    }
  }
}

    return !hasErrors;
  }

  Widget _buildProgramTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
  // Helper method to check if date is valid
  String? validateDate(DateTime? date) {
    if (date == null) return null;
    
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

  // Check for current error
  final currentDateError = _dateError ?? validateDate(_selectedDate);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
            _selectedDate != null
                ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                : 'Select a date',
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

Future<void> _selectDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
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
    setState(() {
      _selectedDate = picked;
      _dateError = null;
    });
  }
}

  Future<void> _updateProgram() async {
    if (!_validateProgram()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstError();
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final programProvider = context.read<ProgramProvider>();

      // Determine new status based on date
      String newStatus = widget.program.status;
      bool shouldReactivate = false;
      
      final bool isCurrentlyCompleted = widget.program.isCompleted;
      final bool isCurrentlyCancelled = widget.program.isCancelled;
      
     // ✅ Fix: Handle nullable _selectedDate
if ((isCurrentlyCompleted || isCurrentlyCancelled) && 
    _selectedDate != null && 
    _selectedDate!.isAfter(DateTime.now())) {
  newStatus = 'active';
  shouldReactivate = true;
}


      
// ✅ Fix: Only check date for non-monthly programs
if (!_isMonthlyPaymentProgram && 
    widget.program.status == 'active' && 
    _selectedDate != null && 
    _selectedDate!.isBefore(DateTime.now())) {
  newStatus = 'completed';
}

  // Create updated program with nullable fields
final updatedProgram = widget.program.copyWith(
  title: _titleController.text.trim(),
  // ✅ Fix: For monthly programs, set programDate to null
  programDate: _isMonthlyPaymentProgram ? null : _selectedDate,
  suggestedContribution: _suggestedContributionController.text.isNotEmpty
      ? double.tryParse(_suggestedContributionController.text)
      : null,
  // ✅ Fix: For monthly programs, totalProgramAmount should be null
  totalProgramAmount: _isMonthlyPaymentProgram 
      ? null 
      : (_totalProgramAmountController.text.isNotEmpty
          ? double.tryParse(_totalProgramAmountController.text)
          : null),
  maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 0,
  participantType: _participantType,
  programType: _programType!,
  isMonthlyPaymentProgram: _isMonthlyPaymentProgram,
  status: newStatus,
);

      await programProvider.updateProgram(updatedProgram);
      if (!mounted) return;
      
      if (mounted) {
        if (shouldReactivate) {
  String dateText = '';
  if (_selectedDate != null) {
    dateText = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
  } else {
    dateText = 'date set';
  }
  
  SnackbarHelper.showSuccess(
    context, 
    'Program reactivated! New date: $dateText'
  );
} else if (isCurrentlyCompleted && newStatus == 'active') {
          SnackbarHelper.showSuccess(
            context, 
            'Program reactivated! It is now active again.'
          );
        } else {
          SnackbarHelper.showSuccess(context, 'Program updated successfully!');
        }
        
        widget.onProgramUpdated?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update program: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProgramStatusWarning(bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.event_busy : Icons.cancel,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCompleted ? 'Program Completed' : 'Program Cancelled',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCompleted
                ? 'This program has ended. Changing the date will reactivate it.'
                : 'This program is cancelled. Changing the date will reactivate it.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isProgramCompleted = widget.program.isCompleted;
    final bool isProgramCancelled = widget.program.isCancelled;

    return GradientSheetScaffold(
      title: 'Edit Program',
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
                        valueColor: AlwaysStoppedAnimation(Colors.white),
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
                              ? const Icon(Icons.check, color: Colors.white, size: 26)
                              : const Icon(Icons.wifi_off, color: Colors.white70, size: 26),
                          tooltip: isOnline
                              ? (widget.program.isCompleted || widget.program.isCancelled)
                                  ? 'Reactivate Program'
                                  : 'Save Changes'
                              : 'Offline - No Connection',
                          onPressed: isOnline ? _updateProgram : null,
                        );
                      },
                    ),
                  );
          },
        ),
      ],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (isProgramCompleted || isProgramCancelled)
                  _buildProgramStatusWarning(isProgramCompleted),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      // Program Title
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
                          final alphabetCount = value.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
                          if (alphabetCount < 3) {
                            return 'Title must have at least 3 alphabet characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Program Type Dropdown
                      _buildProgramTypeDropdown(),
                      const SizedBox(height: 12),

                      // Program Date (Only show for non-monthly programs)
                      if (!_isMonthlyPaymentProgram) ...[
                        _buildDatePickerField(),
                      ],

                      // Suggested Contribution
                      _buildInputField(
                        controller: _suggestedContributionController,
                        label: (_participantType == 'fixed' || _isMonthlyPaymentProgram)
                            ? 'Suggested Contribution'
                            : 'Suggested Contribution (Optional)',
                        icon: Icons.currency_rupee,
                        hint: (_participantType == 'fixed' || _isMonthlyPaymentProgram)
                            ? 'e.g., 500, 1000, 2000'
                            : 'e.g., 500, 1000, 2000 (optional if total amount is set)',
                        maxLength: 10,
                        keyboardType: TextInputType.number,
                        isRequired: _participantType == 'fixed' || _isMonthlyPaymentProgram,
                        focusNode: _contributionFocusNode,
                        validator: (value) {
                          if (_isMonthlyPaymentProgram || _participantType == 'fixed') {
                            if (value == null || value.isEmpty) {
                              return 'Please enter contribution amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                          } else if (_participantType == 'unlimited') {
                            // For unlimited: Not required (can be empty or 0)
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

                      // Total Program Amount (Only show for non-monthly programs)
                      if (!_isMonthlyPaymentProgram)
                        _buildInputField(
                          controller: _totalProgramAmountController,
                          label: 'Total Program Amount',
                          maxLength: 10,
                          icon: Icons.currency_rupee,
                          hint: _participantType == 'unlimited'
                              ? 'Required: Total amount to raise'
                              : 'e.g., 50000, 100000 (optional if contribution is set)',
                          keyboardType: TextInputType.number,
                          isRequired: _participantType == 'unlimited',
                          focusNode: _totalAmountFocusNode,
                          validator: _validateTotalProgramAmount,
                        ),

                      if (!_isMonthlyPaymentProgram) const SizedBox(height: 12),

                      // Participant Type Selection - UPDATED with auto-calculation
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

                      // Show max participants only for fixed type
                      if (_participantType == 'fixed')
                        _buildInputField(
                          controller: _maxParticipantsController,
                          label: 'Maximum Participants',
                          icon: Icons.people,
                          hint: 'e.g., 20, 50, 100',
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          isRequired: true,
                          focusNode: _participantsFocusNode,
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

                      const SizedBox(height: 16),

                      if (isProgramCompleted || isProgramCancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.green, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Setting a future date will change status to "Active"',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
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