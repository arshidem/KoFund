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
  final TextEditingController _contributionController = TextEditingController(text: '0');
  final TextEditingController _totalProgramAmountController = TextEditingController(text: '0');
  final TextEditingController _maxParticipantsController = TextEditingController(text: '50');

  DateTime _selectedDate = DateTime.now();
  String _participantType = 'fixed';
  String _programType = ProgramTypes.general;
  bool _isLoading = false;
  bool _isMonthlyPaymentProgram = false;

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
      body: Container(
        color: AppColors.background(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Program Title
                Card(
                  elevation: 2,
                  color: AppColors.card(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Program Title *',
                        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: AppColors.surface(context),
                      ),
                      validator: (value) => value!.isEmpty ? 'Enter program title' : null,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Description (Optional)
                Card(
                  elevation: 2,
                  color: AppColors.card(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: AppColors.surface(context),
                      ),
                      maxLines: 3,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Program Type Dropdown
                Card(
                  elevation: 2,
                  color: AppColors.card(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: _programType,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      dropdownColor: AppColors.card(context),
                      decoration: InputDecoration(
                        labelText: 'Program Type',
                        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: AppColors.surface(context),
                      ),
                      items: ProgramTypes.allTypes.map((type) {
                        return DropdownMenuItem(
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
                      onChanged: (value) => setState(() => _programType = value!),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Monthly Program Toggle
                Card(
                  elevation: 2,
                  color: AppColors.card(context),
                  child: SwitchListTile(
                    title: Text(
                      'Monthly Payment Program',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Enable for recurring monthly contribution programs',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    value: _isMonthlyPaymentProgram,
                    onChanged: (value) {
                      setState(() => _isMonthlyPaymentProgram = value);
                    },
                    activeColor: AppColors.primary(context),
                  ),
                ),

                const SizedBox(height: 12),

                // Program Date (Only show for non-monthly programs)
                if (!_isMonthlyPaymentProgram)
                  Card(
                    elevation: 2,
                    color: AppColors.card(context),
                    child: ListTile(
                      title: Text(
                        'Program Date *',
                        style: TextStyle(color: AppColors.textPrimary(context)),
                      ),
                      subtitle: Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: TextStyle(color: AppColors.textSecondary(context)),
                      ),
                      trailing: Icon(Icons.calendar_today, color: AppColors.primary(context)),
                      onTap: () => _selectDate(context),
                    ),
                  ),

                if (!_isMonthlyPaymentProgram) const SizedBox(height: 12),

                // Location (Optional)
                Card(
                  elevation: 2,
                  color: AppColors.card(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _locationController,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Location (Optional)',
                        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: AppColors.surface(context),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Suggested Contribution
                Card(
                  elevation: 2,
                  color: AppColors.card(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _contributionController,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Suggested Contribution',
                        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: AppColors.textPrimary(context)),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: AppColors.surface(context),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Enter contribution amount' : null,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Total Program Amount (Only show for non-monthly programs)
                if (!_isMonthlyPaymentProgram)
                  Card(
                    elevation: 2,
                    color: AppColors.card(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _totalProgramAmountController,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Total Program Amount',
                          labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(color: AppColors.textPrimary(context)),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: AppColors.surface(context),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),

                if (!_isMonthlyPaymentProgram) const SizedBox(height: 12),

                // Participant Type
                Card(
                  elevation: 2,
                  color: AppColors.card(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Participant Type',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(
                                  'Fixed Number',
                                  style: TextStyle(color: AppColors.textPrimary(context)),
                                ),
                                value: 'fixed',
                                groupValue: _participantType,
                                activeColor: AppColors.primary(context),
                                onChanged: (value) => setState(() => _participantType = value!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(
                                  'Unlimited',
                                  style: TextStyle(color: AppColors.textPrimary(context)),
                                ),
                                value: 'unlimited',
                                groupValue: _participantType,
                                activeColor: AppColors.primary(context),
                                onChanged: (value) => setState(() => _participantType = value!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Show max participants only for fixed type
                if (_participantType == 'fixed')
                  Card(
                    elevation: 2,
                    color: AppColors.card(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _maxParticipantsController,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Maximum Participants *',
                          labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: AppColors.surface(context),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_participantType == 'fixed' && (value == null || value.isEmpty)) {
                            return 'Enter max participants';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                
                // Create Button
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createProgram,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading 
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Create Program',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createProgram() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for non-monthly programs
    if (!_isMonthlyPaymentProgram) {
      // For non-monthly programs, check if date is valid
      if (_selectedDate.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a future date for the program'),
            backgroundColor: AppColors.error(context),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AppAuthProvider>();
      final programProvider = context.read<ProgramProvider>();

      final program = ProgramModel(
        programId: '', // Will be set by Firestore
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
        programType: _programType,
        isMonthlyPaymentProgram: _isMonthlyPaymentProgram,
      );

      await programProvider.createProgram(program);
      
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Program created successfully!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create program: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}