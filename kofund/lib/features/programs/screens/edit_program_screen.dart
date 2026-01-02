// lib/features/programs/screens/edit_program_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import '../providers/program_provider.dart';
import '../models/program_model.dart';
import 'package:kofund/core/services/network_service.dart';

class EditProgramScreen extends StatefulWidget {
  final ProgramModel program;
  final VoidCallback? onProgramUpdated;

  const EditProgramScreen({
    Key? key,
    required this.program,
    this.onProgramUpdated,
  }) : super(key: key);

  @override
  State<EditProgramScreen> createState() => _EditProgramScreenState();
}

class _EditProgramScreenState extends State<EditProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _suggestedContributionController = TextEditingController();
  final TextEditingController _totalProgramAmountController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
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
  }

  void _initializeForm() {
    final program = widget.program;
    
    _titleController.text = program.title;
    _descriptionController.text = program.description;
    _locationController.text = program.location;
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
    _descriptionController.dispose();
    _locationController.dispose();
    _suggestedContributionController.dispose();
    _totalProgramAmountController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

Widget _buildInputField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  required String hint,
  bool obscureText = false,
  bool showObscureToggle = false,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  int maxLength = 50, // DEFAULT TO 50
  List<TextInputFormatter>? inputFormatters,
  String? errorText,
  bool isRequired = false,
  bool showCharacterCounter = false, // Add this for title field
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
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength, // Show the counter
        maxLengthEnforcement: MaxLengthEnforcement.enforced, // Prevent typing after limit
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
          counterText: showCharacterCounter ? '' : null, // Hide default counter if we show custom one
        ),
      ),
      
      // Custom character counter for title field
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
  Widget _buildProgramTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _programTypeError != null 
                  ? Colors.red.withOpacity(0.8) 
                  : AppColors.border(context),
              width: _programTypeError != null ? 1.5 : 1,
            ),
            color: _programTypeError != null 
                ? Colors.red.withOpacity(0.03) 
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
                        ? Colors.red.withOpacity(0.7) 
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
                          color: AppColors.primary(context).withOpacity(0.1),
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

    // Check for current error
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
                  ? Colors.red.withOpacity(0.8) 
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
                    ? Colors.red.withOpacity(0.8) 
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
        
        // Show inline error message
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
      setState(() {
        _selectedDate = picked;
        _dateError = null; // Clear error when user selects a new date
      });
    }
  }

  Future<void> _updateProgram() async {
    // Clear previous errors
    setState(() {
      _programTypeError = null;
      _dateError = null;
    });

    // 1. VALIDATE ALL FIELDS AND SHOW ALL ERRORS AT ONCE
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

    // Check contribution amount
    if (_suggestedContributionController.text.isEmpty || 
        double.tryParse(_suggestedContributionController.text) == null ||
        double.parse(_suggestedContributionController.text) <= 0) {
      hasErrors = true;
    }

    // For fixed participants, check max participants
    if (_participantType == 'fixed' && 
        (_maxParticipantsController.text.isEmpty || 
         int.tryParse(_maxParticipantsController.text) == null ||
         int.parse(_maxParticipantsController.text) <= 0)) {
      hasErrors = true;
    }

    // For non-monthly programs, validate date
    if (!_isMonthlyPaymentProgram) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final selectedOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      
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

    // If any errors exist, stop here
    if (hasErrors) {
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
      
      // Check if we're changing from completed/cancelled to active
      final bool isCurrentlyCompleted = widget.program.isCompleted;
      final bool isCurrentlyCancelled = widget.program.isCancelled;
      
      // If program was completed/cancelled AND new date is in future, reactivate
      if ((isCurrentlyCompleted || isCurrentlyCancelled) && 
          _selectedDate.isAfter(DateTime.now())) {
        newStatus = 'active';
        shouldReactivate = true;
      }
      
      // If program was active AND new date is in past, complete it
      if (widget.program.status == 'active' && 
          _selectedDate.isBefore(DateTime.now())) {
        newStatus = 'completed';
      }

      // Create updated program
      final updatedProgram = widget.program.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        programDate: _selectedDate,
        location: _locationController.text.trim(),
        suggestedContribution: _suggestedContributionController.text.isNotEmpty
            ? double.tryParse(_suggestedContributionController.text)
            : null,
        totalProgramAmount: _totalProgramAmountController.text.isNotEmpty
            ? double.tryParse(_totalProgramAmountController.text)
            : null,
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 0,
        participantType: _participantType,
        programType: _programType!,
        isMonthlyPaymentProgram: _isMonthlyPaymentProgram,
        status: newStatus,
      );

      await programProvider.updateProgram(updatedProgram);
      
      if (mounted) {
        // Show appropriate success message
        if (shouldReactivate) {
          SnackbarHelper.showSuccess(
            context, 
            'Program reactivated! New date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
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

  @override
  Widget build(BuildContext context) {
    final bool isProgramCompleted = widget.program.isCompleted;
    final bool isProgramCancelled = widget.program.isCancelled;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Text(
          'Edit Program',
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
      actions: [
  // Use StatefulBuilder to show/hide based on loading state
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
              padding: const EdgeInsets.only(right: 8), // Add right padding here
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 🆕 Warning for completed/cancelled programs
                if (isProgramCompleted || isProgramCancelled)
                  _buildProgramStatusWarning(isProgramCompleted),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      // Program Title
               // Program Title
// Program Title
_buildInputField(
  controller: _titleController,
  label: 'Program Title',
  icon: Icons.event,
  hint: 'e.g., Monthly Savings, Trip to Goa, Birthday Fund',
  isRequired: true,
  maxLength: 50,
  showCharacterCounter: true, // Add this line
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

                      // Description
                      _buildInputField(
                        controller: _descriptionController,
                        label: 'Description',
                        icon: Icons.description,
                        hint: 'Describe the program purpose, activities, rules...',
                        maxLines: 3,
                        maxLength: 200,
                      ),
                      const SizedBox(height: 12),

                      // Location
                      _buildInputField(
                        controller: _locationController,
                        label: 'Location',
                        icon: Icons.location_on,
                         maxLength: 20,
                        hint: 'e.g., Community Hall, Online Meeting, Resort Name',
                        validator: (value) {
                          // Location is optional, no validation needed
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Suggested Contribution
                      _buildInputField(
                        controller: _suggestedContributionController,
                        label: 'Suggested Contribution',
                        icon: Icons.currency_rupee,
                        hint: 'e.g., 500, 1000, 2000',
                        maxLength: 10,
                        keyboardType: TextInputType.number,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter contribution amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
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
                          hint: 'e.g., 50000, 100000 (optional)',
                          keyboardType: TextInputType.number,
                       
                        ),

                      if (!_isMonthlyPaymentProgram) const SizedBox(height: 12),

                      // Participant Type Selection
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
                                    onChanged: (value) => setState(() => _participantType = value!),
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
                                    onChanged: (value) => setState(() => _participantType = value!),
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

                      // 🆕 Reactivate Info (only for completed/cancelled programs)
                      if (isProgramCompleted || isProgramCancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
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

                      // Action Buttons
                   // Action Button (without cancel button)
FutureBuilder<bool>(
  future: NetworkService().isConnected, // Initial check
  builder: (context, snapshot) {
    final bool isOnline = snapshot.data ?? true;
    
    return StreamBuilder<bool>(
      stream: NetworkService().onConnectionChanged,
      builder: (context, streamSnapshot) {
        // Use stream data if available, otherwise use future data
        final bool currentIsOnline = streamSnapshot.data ?? isOnline;
        final bool isDisabled = _isLoading || !currentIsOnline;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isDisabled ? null : _updateProgram,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary(context).withOpacity(0.5),
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
                            currentIsOnline 
                              ? (isProgramCompleted || isProgramCancelled) 
                                ? Icons.refresh 
                                : Icons.save
                              : Icons.wifi_off,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            currentIsOnline 
                              ? (isProgramCompleted || isProgramCancelled) 
                                ? 'Reactivate Program' 
                                : 'Update Program'
                              : 'Offline',
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

  Widget _buildProgramStatusWarning(bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
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
}