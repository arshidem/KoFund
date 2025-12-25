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

class _CreateProgramScreenState extends State<CreateProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _contributionController = TextEditingController(text: '');
  final TextEditingController _totalProgramAmountController = TextEditingController(text: '');
  final TextEditingController _maxParticipantsController = TextEditingController(text: '50');

 DateTime _selectedDate = DateTime.now().add(const Duration(days: 10));
  String? _dateError; // Add this for date validation error  
  String _participantType = 'fixed';
  String? _programType;
  bool _isLoading = false;
  bool _isMonthlyPaymentProgram = false;
  String? _programTypeError;

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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contributionController.dispose();
    _totalProgramAmountController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
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
          counterText: '', // Always hide default counter
        ),
      ),
      
      // Custom character counter (only show when field is focused or has text)
      if (showCharacterCounter)
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Focus(
              onFocusChange: (hasFocus) {
                // This triggers rebuild when focus changes
                setState(() {});
              },
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final currentLength = value.text.length;
                  final remaining = maxLength - currentLength;
                  final hasText = currentLength > 0;
                  
                  // Get focus state
                  final FocusNode? focusNode = Focus.of(context);
                  final bool isFocused = focusNode?.hasFocus ?? false;
                  
                  // Show counter only if field is focused OR has text
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
                  
                  // Return empty container when not focused and no text
                  return const SizedBox.shrink();
                },
              ),
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

  Future<void> _createProgram() async {
  // Clear previous errors
  setState(() {
    _programTypeError = null;
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
  if (_contributionController.text.isEmpty || 
      double.tryParse(_contributionController.text) == null ||
      double.parse(_contributionController.text) <= 0) {
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
      hasErrors = true;
      // The error will automatically show in _buildDatePickerField
      // because it validates the current _selectedDate
    }
  }

  // If any errors exist, stop here
  if (hasErrors) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFirstError();
    });
    return;
  }

  // 2. Continue with program creation...
  setState(() => _isLoading = true);

  try {
    final authProvider = context.read<AppAuthProvider>();
    final programProvider = context.read<ProgramProvider>();

    final program = ProgramModel(
      programId: '',
      communityId: authProvider.user!.communityId!,
      title: _titleController.text,
      description: _descriptionController.text.trim(),
      programDate: _isMonthlyPaymentProgram ? DateTime.now() : _selectedDate,
      location: _locationController.text.trim(),
      suggestedContribution: double.parse(_contributionController.text),
      totalProgramAmount: _isMonthlyPaymentProgram 
          ? null 
          : (_totalProgramAmountController.text.isNotEmpty 
              ? double.tryParse(_totalProgramAmountController.text)
              : null),
      maxParticipants: _participantType == 'fixed' 
          ? int.parse(_maxParticipantsController.text)
          : 0,
      participantType: _participantType,
      status: 'active',
      createdBy: authProvider.user!.uid,
      createdAt: Timestamp.now(),
      programType: _programType!,
      isMonthlyPaymentProgram: _isMonthlyPaymentProgram,
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
                // Logo Header (similar to CreateCommunityScreen)
          
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
        showCharacterCounter: true, // Add this line
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

      // Program Type Dropdown
      _buildProgramTypeDropdown(),

      const SizedBox(height: 12),

      // Monthly Program Toggle
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
                showCharacterCounter: true, // Add this line

        maxLength: 200,
      ),
      const SizedBox(height: 12),

      // Location
      _buildInputField(
        controller: _locationController,
        label: 'Location',
        icon: Icons.location_on,
        hint: 'e.g., Community Hall, Online Meeting, Resort Name',
        maxLength: 100,
        showCharacterCounter: true, // Add this line
        validator: (value) {
          // Location is optional, no validation needed
          return null;
        },
      ),
      const SizedBox(height: 12),

      // Suggested Contribution
      _buildInputField(
        controller: _contributionController,
        label: 'Suggested Contribution',
        icon: Icons.currency_rupee,
        hint: 'e.g., 500, 1000, 2000',
        showCharacterCounter: true,
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
          icon: Icons.currency_rupee,
          hint: 'e.g., 50000, 100000 (optional)',
          maxLength: 10,
          showCharacterCounter: true,
          keyboardType: TextInputType.number,
          validator: (value) {
            // Optional field
            if (value != null && value.isNotEmpty) {
              final amount = double.tryParse(value);
              if (amount != null && amount <= 0) {
                return 'Please enter a valid amount';
              }
            }
            return null;
          },
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
          showCharacterCounter: true,
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

      const SizedBox(height: 12),

  // Create Button - Alternative with centered content
// Replace your current Create Button with this:
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
                onPressed: isDisabled ? null : _createProgram,
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