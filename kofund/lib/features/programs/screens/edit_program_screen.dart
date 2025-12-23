// lib/features/programs/screens/edit_program_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import '../providers/program_provider.dart';
import '../models/program_model.dart';

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
  String _selectedProgramType = ProgramTypes.general; // ✅ Use constant
  String _selectedParticipantType = 'fixed';
  bool _isMonthlyPaymentProgram = false;
  bool _isLoading = false;

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
    _selectedProgramType = program.programType;
    _selectedParticipantType = program.participantType;
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

Future<void> _updateProgram() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final programProvider = context.read<ProgramProvider>();
    final authProvider = context.read<AppAuthProvider>();

    // 🆕 Determine new status based on date
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
      participantType: _selectedParticipantType,
      programType: _selectedProgramType,
      isMonthlyPaymentProgram: _isMonthlyPaymentProgram,
      status: newStatus, // 🆕 Update status
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
      
      // ✅ Call the callback if provided
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

Future<void> _selectDate() async {
  // Add this check
  if (!mounted) return;
  
  try {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != _selectedDate) {
      if (!mounted) return;
      setState(() => _selectedDate = picked);
    }
  } catch (e) {
    print('Error in date picker: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select date: $e')),
      );
    }
  }
}

@override
Widget build(BuildContext context) {
  final bool isProgramCompleted = widget.program.isCompleted;
  final bool isProgramCancelled = widget.program.isCancelled;

  return Scaffold(
    backgroundColor: AppColors.background(context),
appBar: AppBar(
  toolbarHeight: 80, // Added from Members app bar
  title: const Text(
    'Edit Program', // Added TextStyle
    style: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  centerTitle: true, // Added from Members app bar
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white, // Added for white icons
  elevation: 0,
  systemOverlayStyle: SystemUiOverlayStyle( // Added from Members app bar
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background(context),
    systemNavigationBarIconBrightness: Brightness.dark,
  ),
  flexibleSpace: Container( // Added from Members app bar
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
    ),
  ),
  leading: IconButton( // Added from Members app bar
    icon: const Icon(
      Icons.arrow_back,
      color: Colors.white, // Explicit white color
    ),
    onPressed: () => Navigator.pop(context),
  ),
  automaticallyImplyLeading: true, // Added for consistency
  actions: [
    if (_isLoading)
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white), // Changed to white to match theme
          ),
        ),
      ),
  ],
),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // 🆕 Warning for completed/cancelled programs
              if (isProgramCompleted || isProgramCancelled)
                _buildProgramStatusWarning(isProgramCompleted),
              
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              _buildBasicInfoSection(),

              const SizedBox(height: 24),

              // Financial Information Section
              _buildSectionHeader('Financial Information'),
              _buildFinancialSection(),

              const SizedBox(height: 24),

              // Program Settings Section
              _buildSectionHeader('Program Settings'),
              _buildProgramSettingsSection(),

              const SizedBox(height: 32),

              // Action Buttons
              _buildActionButtons(isProgramCompleted, isProgramCancelled),
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildProgramStatusWarning(bool isCompleted) {
  return Card(
    color: Colors.orange.withOpacity(0.1),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      color: AppColors.card(context),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Program Title *',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a program title';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description (Optional)
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location (Optional)
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location (Optional)',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Program Date (Only show for non-monthly programs)
            if (!_isMonthlyPaymentProgram)
        // Alternative simple solution
GestureDetector(
  onTap: _selectDate,
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border(context)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Program Date *',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        Icon(
          Icons.calendar_today,
          color: AppColors.primary(context),
        ),
      ],
    ),
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSection() {
    return Card(
      color: AppColors.card(context),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Suggested Contribution
            TextFormField(
              controller: _suggestedContributionController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Suggested Contribution (₹)',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
                prefixText: '₹ ',
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0) {
                    return 'Please enter a valid amount';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Total Program Amount (Only show for non-monthly programs)
            if (!_isMonthlyPaymentProgram)
              TextFormField(
                controller: _totalProgramAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Total Program Amount (₹)',
                  labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                  ),
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final amount = double.tryParse(value);
                    if (amount == null || amount < 0) {
                      return 'Please enter a valid amount';
                    }
                  }
                  return null;
                },
              ),


         
          ],
        ),
      ),
    );
  }

  Widget _buildProgramSettingsSection() {
    return Card(
      color: AppColors.card(context),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ UPDATED: Program Type using ProgramTypes
            DropdownButtonFormField<String>(
              value: _selectedProgramType,
              decoration: InputDecoration(
                labelText: 'Program Type',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
              ),
              items: ProgramTypes.allTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        ProgramTypes.getIconData(type),
                        color: AppColors.primary(context),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ProgramTypes.getDisplayName(type),
                        style: TextStyle(color: AppColors.textPrimary(context)),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedProgramType = value!);
              },
            ),

            const SizedBox(height: 16),

            // Participant Type
            DropdownButtonFormField<String>(
              value: _selectedParticipantType,
              decoration: InputDecoration(
                labelText: 'Participant Type',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: 'fixed',
                  child: Text(
                    'Fixed Participants',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'unlimited',
                  child: Text(
                    'Unlimited Participants',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedParticipantType = value!);
              },
            ),

            const SizedBox(height: 16),

            // Max Participants (only show for fixed type)
            if (_selectedParticipantType == 'fixed')
              TextFormField(
                controller: _maxParticipantsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Maximum Participants *',
                  labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                  ),
                ),
                validator: (value) {
                  if (_selectedParticipantType == 'fixed') {
                    if (value == null || value.isEmpty) {
                      return 'Please enter maximum participants';
                    }
                    final count = int.tryParse(value);
                    if (count == null || count <= 0) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
    );
  }

 Widget _buildActionButtons(bool isCompleted, bool isCancelled) {
  return Column(
    children: [
      // 🆕 Reactivate Info (only for completed/cancelled programs)
      if (isCompleted || isCancelled)
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
      
      Row(
        children: [
          // Cancel Button
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary(context),
                side: BorderSide(color: AppColors.border(context)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),

          const SizedBox(width: 16),

          // Update Button with dynamic text
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updateProgram,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      (isCompleted || isCancelled) 
                        ? 'Reactivate Program' 
                        : 'Update Program'
                    ),
            ),
          ),
        ],
      ),
    ],
  );
}
}