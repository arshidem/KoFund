// lib/features/history/widgets/add_expense_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/program_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/services/user_service.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../../features/expenses/models/expense_model.dart';
import '../../../features/programs/models/program_model.dart';
import '../../../core/constants/app_colors.dart';

class AddExpenseModal extends StatefulWidget {
  const AddExpenseModal({Key? key}) : super(key: key);

  @override
  State<AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  final _expenseService = ExpenseService();
  final _programService = ProgramService();
  final _userService = UserService();
  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  ProgramModel? _selectedProgram;
  String _title = '';
  String _description = '';
  double _amount = 0;
  String _category = 'other';
  DateTime _expenseDate = DateTime.now();
  bool _isLoading = false; // Add this line
  
  // For character counters
  int _titleLength = 0;
  int _descriptionLength = 0;
  
  // For program loading
  bool _isLoadingPrograms = true;
  List<ProgramModel> _programs = [];
  String? _programsError;
  
  final List<String> _categories = [
    'food', 'transport', 'materials', 'venue', 'equipment', 'other'
  ];

@override
void initState() {
  super.initState();
  
  // Add listeners for character counters
  _titleController.addListener(() {
    setState(() {
      _titleLength = _titleController.text.length;
    });
  });
  
  _descriptionController.addListener(() {
    setState(() {
      _descriptionLength = _descriptionController.text.length;
    });
  });
  
  // Load programs after the widget is built
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadPrograms();
  });
}

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

Future<void> _loadPrograms() async {
  try {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPrograms = true;
      _programsError = null;
    });

    // Get auth from context (now it's available)
    final auth = context.read<AppAuthProvider>();
    final communityId = auth.user?.communityId ?? '';
    final isAdmin = auth.user?.isAdmin == true;
    final currentUserId = auth.user?.uid ?? '';

    List<ProgramModel> programs;
    if (isAdmin) {
      programs = await _programService.getActiveProgramsByCommunity(communityId);
    } else {
      programs = await _getUserPrograms(communityId, currentUserId);
    }

    if (mounted) {
      setState(() {
        _programs = programs;
        _isLoadingPrograms = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _programsError = e.toString();
        _isLoadingPrograms = false;
      });
    }
  }
}

  Future<List<ProgramModel>> _getUserPrograms(String communityId, String userId) async {
    final allPrograms = await _programService.getActiveProgramsByCommunity(communityId);
    final userPrograms = <ProgramModel>[];

    for (final program in allPrograms) {
      final isInProgram = await _userService.isUserInProgram(userId, program.programId);
      if (isInProgram) {
        userPrograms.add(program);
      }
    }

    return userPrograms;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final isAdmin = auth.user?.isAdmin == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          color: Theme.of(context).colorScheme.background,
        ),
        child: Column(
          children: [
            // Header with gradient
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Main header row
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 16, 
                      left: 16, 
                      top: 40, 
                      bottom: 16,
                    ),
                    child: Row(
                      children: [
                        // Back button
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        
                        // Spacer to push title to center
                        Expanded(
                          child: Center(
                            child: Text(
                              'Add Expense',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        
                        // Empty container to balance the left icon button
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // Info section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, 
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAdmin ? Icons.verified : Icons.pending_actions,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isAdmin 
                                ? 'This expense will be automatically approved (Admin)'
                                : 'This expense requires admin approval',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Program selection
                      _buildProgramSelection(),
                      const SizedBox(height: 20),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Expense Title *',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          counterText: '$_titleLength/50',
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: _titleLength > 45 
                                ? Colors.orange 
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        maxLength: 50,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 14,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter expense title';
                          }
                          if (value.length < 3) {
                            return 'Title must be at least 3 characters';
                          }
                          return null;
                        },
                        onChanged: (value) => _title = value,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          counterText: '$_descriptionLength/200',
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: _descriptionLength > 190 
                                ? Colors.orange 
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        maxLines: 3,
                        maxLength: 200,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 14,
                        ),
                        onChanged: (value) => _description = value,
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Amount (₹) *',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          prefixText: '₹ ',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          counterText: 'Max: 10 digits',
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 14,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null) {
                            return 'Please enter a valid number';
                          }
                          if (amount <= 0) {
                            return 'Amount must be greater than 0';
                          }
                          if (amount > 9999999.99) {
                            return 'Amount cannot exceed ₹ 99,99,999.99';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _amount = double.tryParse(value) ?? 0;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 14,
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(
                              category[0].toUpperCase() + category.substring(1),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _category = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Expense date
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Expense Date:',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onBackground,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _selectDate(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_expenseDate),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                   SizedBox(
  width: double.infinity,
  child: FutureBuilder<bool>(
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
              ElevatedButton(
                onPressed: isDisabled ? null : _submitExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
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
                            currentIsOnline ? Icons.add : Icons.wifi_off,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            currentIsOnline ? 'Add Expense' : 'Offline',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
)
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramSelection() {
    if (_isLoadingPrograms) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading programs...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ],
        ),
      );
    }

    if (_programsError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Error loading programs',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _programsError!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadPrograms,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_programs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[100]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info,
              color: Colors.blue[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No programs available',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You need to join or create a program first',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<ProgramModel>(
      value: _selectedProgram,
      decoration: InputDecoration(
        labelText: 'Program *',
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: Icon(
          Icons.assignment,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onBackground,
        fontSize: 14,
      ),
      items: [
        DropdownMenuItem<ProgramModel>(
          value: null,
          child: Text(
            'Select a program',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        ..._programs.map((program) {
          return DropdownMenuItem(
            value: program,
            child: Text(
              program.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ],
      onChanged: (program) {
        setState(() {
          _selectedProgram = program;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Please select a program';
        }
        return null;
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    
    if (picked != null && picked != _expenseDate) {
      final today = DateTime.now();
      final maxDate = today.add(const Duration(days: 30));
      
      if (picked.isAfter(maxDate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot add expenses more than 30 days in future'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgram == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a program'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final isAdmin = auth.user?.isAdmin == true;
    final currentUserId = auth.user?.uid ?? '';
    final currentUser = auth.user?.displayName ?? '';

    try {
      final expense = ExpenseModel(
        expenseId: '', // Will be set by Firestore
        programId: _selectedProgram!.programId,
        communityId: _selectedProgram!.communityId,
        title: _title,
        description: _description,
        amount: _amount,
        category: _category,
        paidBy: currentUserId,
        paidByName: currentUser,
        expenseDate: _expenseDate,
        status: isAdmin ? 'approved' : 'pending',
        createdAt: Timestamp.now(),
      );

      await _expenseService.createExpense(expense);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdmin 
              ? 'Expense added and approved!'
              : 'Expense added! Waiting for admin approval.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context); // Close modal
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding expense: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}