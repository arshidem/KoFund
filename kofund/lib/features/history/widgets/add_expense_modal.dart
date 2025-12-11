// lib/features/history/widgets/add_expense_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/program_service.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/services/user_service.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../../features/expenses/models/expense_model.dart';
import '../../../features/programs/models/program_model.dart';
import '../../../features/auth/models/user_model.dart';

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
  ProgramModel? _selectedProgram;
  String _title = '';
  String _description = '';
  double _amount = 0;
  String _category = 'other';
  DateTime _expenseDate = DateTime.now();
  final List<String> _categories = [
    'food', 'transport', 'materials', 'venue', 'equipment', 'other'
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final communityId = auth.user?.communityId ?? '';
    final isAdmin = auth.user?.isAdmin == true;
    final currentUserId = auth.user?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Expense',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Program selection
                    _buildProgramSelection(communityId, isAdmin, currentUserId),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Expense Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter expense title';
                        }
                        return null;
                      },
                      onChanged: (value) => _title = value,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                      onChanged: (value) => _description = value,
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter valid amount';
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
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category[0].toUpperCase() + category.substring(1)),
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
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Expense Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_expenseDate.day}/${_expenseDate.month}/${_expenseDate.year}',
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Status info
                    Card(
                      color: isAdmin ? Colors.green[50] : Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              isAdmin ? Icons.verified : Icons.pending,
                              color: isAdmin ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isAdmin 
                                  ? 'This expense will be automatically approved (Admin)'
                                  : 'This expense requires admin approval',
                                style: TextStyle(
                                  color: isAdmin ? Colors.green[800] : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitExpense,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Add Expense'),
                      ),
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

  Widget _buildProgramSelection(String communityId, bool isAdmin, String currentUserId) {
    return FutureBuilder<List<ProgramModel>>(
      future: isAdmin 
          ? _programService.getActiveProgramsByCommunity(communityId)
          : _getUserPrograms(communityId, currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final programs = snapshot.data ?? [];

        return DropdownButtonFormField<ProgramModel>(
          decoration: InputDecoration(
            labelText: 'Program',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          value: _selectedProgram,
          items: programs.map((program) {
            return DropdownMenuItem(
              value: program,
              child: Text(program.title),
            );
          }).toList(),
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
      },
    );
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgram == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a program')),
      );
      return;
    }

    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final isAdmin = auth.user?.isAdmin == true;
    final currentUserId = auth.user?.uid ?? '';

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
        expenseDate: _expenseDate,
        status: isAdmin ? 'approved' : 'pending',
        createdAt: Timestamp.now(),
      );

      await _expenseService.createExpense(expense);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          isAdmin 
            ? 'Expense added and approved!'
            : 'Expense added! Waiting for admin approval.'
        )),
      );

      Navigator.pop(context); // Close modal
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding expense: $e')),
      );
    }
  }
}