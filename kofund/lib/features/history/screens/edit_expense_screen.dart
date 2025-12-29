// edit_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../expenses/models/expense_model.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../programs/models/program_model.dart';
import '../../programs/providers/program_provider.dart';
import '../widgets/custom_text_field.dart';

class EditExpenseScreen extends StatefulWidget {
  final String expenseId;
  final Function(ExpenseModel?) onSave;

  const EditExpenseScreen({
    Key? key,
    required this.expenseId,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditExpenseScreenState createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _editReasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _referenceController = TextEditingController();

  // Form values
  String? _selectedProgramId;
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Store fetched expense
  ExpenseModel? _expense;
  List<ProgramModel> _availablePrograms = [];

  // Available categories (from your ProgramExpensesTab)
  final List<String> _categories = [
    'food',
    'transport',
    'venue',
    'materials',
    'decorations',
    'other'
  ];

  // Available payment methods
  final List<String> _paymentMethods = [
    'cash',
    'bank_transfer',
    'upi',
    'cheque',
    'credit_card',
    'debit_card',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _fetchExpenseAndPrograms();
  }

  Future<void> _fetchExpenseAndPrograms() async {
    try {
      print('🔄 Fetching expense with ID: ${widget.expenseId}');
      
      // First try with the given ID
      var docRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId);
      
      var snapshot = await docRef.get();
      
      // If not found, try adding 'expense_' prefix
      if (!snapshot.exists && !widget.expenseId.startsWith('expense_')) {
        print('⚠️ Not found, trying with "expense_" prefix...');
        docRef = FirebaseFirestore.instance
            .collection('expenses')
            .doc('expense_${widget.expenseId}');
        snapshot = await docRef.get();
      }
      
      if (!snapshot.exists) {
        throw Exception('Expense not found with ID: ${widget.expenseId}');
      }
      
      final data = snapshot.data();
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Expense data is invalid');
      }
      
      // Create ExpenseModel from Firestore data
      _expense = ExpenseModel.fromMap(data, snapshot.id);
      
      print('✅ Expense fetched successfully');
      print('   Title: ${_expense!.title}');
      print('   Amount: ${_expense!.amount}');
      print('   Program ID: ${_expense!.programId}');
      print('   Community ID: ${_expense!.communityId}');
      
      // Fetch available programs for this community
      await _fetchAvailablePrograms(_expense!.communityId);
      
      // Initialize form values
      _titleController.text = _expense!.title;
      _descriptionController.text = _expense!.description;
      _amountController.text = _expense!.amount.toStringAsFixed(2);
      _selectedProgramId = _expense!.programId;
      _selectedCategory = _expense!.category;
      _selectedPaymentMethod = _expense!.paymentMethod;
      _selectedDate = _expense!.expenseDate;
      _vendorController.text = _expense!.vendorName ?? '';
      _referenceController.text = _expense!.referenceNumber ?? '';
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Error fetching expense: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchAvailablePrograms(String communityId) async {
    try {
      print('📋 Fetching programs for community: $communityId');
      
      // Use the FirebaseFirestore directly since ProgramProvider doesn't have getProgramsByCommunity
      final querySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('programs')
          .where('status', whereIn: ['active', 'ongoing'])
          .get();
      
      _availablePrograms = querySnapshot.docs.map((doc) {
        return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      print('✅ Found ${_availablePrograms.length} programs');
      
      // If no programs found in subcollection, try root programs collection
      if (_availablePrograms.isEmpty) {
        print('⚠️ No programs in subcollection, trying root collection...');
        final rootQuery = await FirebaseFirestore.instance
            .collection('programs')
            .where('communityId', isEqualTo: communityId)
            .where('status', whereIn: ['active', 'ongoing'])
            .get();
        
        _availablePrograms = rootQuery.docs.map((doc) {
          return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        print('✅ Found ${_availablePrograms.length} programs in root collection');
      }
      
      // Ensure the current program is in the list
      if (_expense != null && !_availablePrograms.any((p) => p.programId == _expense!.programId)) {
        // Try to fetch the specific program to add to list
        try {
          // Try community subcollection first
          final programDoc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('programs')
              .doc(_expense!.programId)
              .get();
          
          if (programDoc.exists) {
            final program = ProgramModel.fromMap(programDoc.data() as Map<String, dynamic>, programDoc.id);
            _availablePrograms.add(program);
            print('➕ Added current program from subcollection');
          } else {
            // Try root collection
            final rootProgramDoc = await FirebaseFirestore.instance
                .collection('programs')
                .doc(_expense!.programId)
                .get();
            
            if (rootProgramDoc.exists) {
              final program = ProgramModel.fromMap(rootProgramDoc.data() as Map<String, dynamic>, rootProgramDoc.id);
              _availablePrograms.add(program);
              print('➕ Added current program from root collection');
            }
          }
        } catch (e) {
          print('⚠️ Could not fetch current program: $e');
        }
      }
      
      // Sort programs by name
      _availablePrograms.sort((a, b) => a.title.compareTo(b.title));
      
    } catch (e) {
      print('❌ Error fetching programs: $e');
      _availablePrograms = [];
    }
  }

  // Helper function to get program name by ID
  String _getProgramNameById(String programId) {
    try {
      final program = _availablePrograms.firstWhere(
        (p) => p.programId == programId,
        orElse: () => ProgramModel(
          programId: programId,
          communityId: _expense?.communityId ?? '',
          title: 'Program $programId',
          description: '',
          programDate: DateTime.now(),
          location: '',
          maxParticipants: 0,
          participantType: 'fixed',
          status: 'active',
          createdBy: '',
          createdAt: Timestamp.now(),
          programType: 'general',
          isMonthlyPaymentProgram: false,
        ),
      );
      return program.title;
    } catch (e) {
      return 'Program $programId';
    }
  }

  // Format category name for display
  String _formatCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food': return 'Food & Beverages';
      case 'transport': return 'Transportation';
      case 'venue': return 'Venue Rental';
      case 'materials': return 'Materials & Supplies';
      case 'decorations': return 'Decorations';
      case 'other': return 'Other Expenses';
      default: return category;
    }
  }

  // Format payment method for display
  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash': return 'Cash';
      case 'upi': return 'UPI';
    
      default: return method;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

Future<void> _saveChanges() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  if (_expense == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense data not loaded'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // Get current user info
  final authProvider = context.read<AppAuthProvider>();
  final currentUser = authProvider.user;
  
  if (currentUser == null) {
    throw Exception('User not authenticated');
  }

  // Check if user is admin
  final bool isAdmin = currentUser.isAdmin == true && currentUser.isApproved == true;

  print('👤 User is Admin: $isAdmin');
  print('📊 Current expense status: ${_expense!.status}');

  // Parse amount
  final amountText = _amountController.text;
  final newAmount = double.tryParse(amountText) ?? 0.0;

  // Check if there are actual changes (excluding status for now)
  bool hasChanges = newAmount != _expense!.amount ||
      _titleController.text.trim() != _expense!.title ||
      _descriptionController.text.trim() != _expense!.description ||
      _selectedProgramId != _expense!.programId ||
      _selectedCategory != _expense!.category ||
      _selectedPaymentMethod != _expense!.paymentMethod ||
      _selectedDate != _expense!.expenseDate ||
      _vendorController.text.trim() != (_expense!.vendorName ?? '') ||
      _referenceController.text.trim() != (_expense!.referenceNumber ?? '');

  if (!hasChanges) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No changes detected'),
        backgroundColor: Colors.orange,
      ),
    );
    widget.onSave(null);
    return;
  }

  // Get edit reason
  String editReason = _editReasonController.text.trim();
  if (editReason.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please provide a reason for editing'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    final expenseProvider = context.read<ExpenseProvider>();
    
    if (!isAdmin) {
      // ===================================================
      // NON-ADMIN USER FLOW (2-step process)
      // ===================================================
      print('🔄 Non-admin user detected - using 2-step update');
      
      // Step 1: Update all other fields using regular updateExpense
      print('📝 Step 1: Updating expense fields...');
      
      // Create updated expense but keep original status temporarily
      final updatedExpense = _expense!.copyWith(
        expenseId: widget.expenseId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: newAmount,
        programId: _selectedProgramId ?? _expense!.programId,
        category: _selectedCategory ?? _expense!.category,
        paymentMethod: _selectedPaymentMethod,
        expenseDate: _selectedDate,
        vendorName: _vendorController.text.trim().isNotEmpty 
            ? _vendorController.text.trim() 
            : null,
        referenceNumber: _referenceController.text.trim().isNotEmpty 
            ? _referenceController.text.trim() 
            : null,
        // Keep current status temporarily - will be updated in step 2
        status: _expense!.status,
        editReason: editReason,
        isEdited: true,
        lastEditedByUserId: currentUser.uid,
        lastEditedByUserName: currentUser.displayName ?? 'User',
        lastEditedAt: Timestamp.now(),
      );
      
      await expenseProvider.updateExpense(
        updatedExpense,
        editedByUserId: currentUser.uid,
        editedByUserName: currentUser.displayName ?? 'User',
        editReason: editReason,
      );
      
      // Step 2: Update status to "pending" using updateExpenseStatus
      print('🔄 Step 2: Changing status to "pending"...');
      await expenseProvider.updateExpenseStatus(widget.expenseId, 'pending');
      
      // Create final expense model with pending status
      final finalExpense = updatedExpense.copyWith(
        status: 'pending',
      );
      
      widget.onSave(finalExpense);
      
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Expense updated. Status changed to "Pending" for admin approval.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      
    } else {
      // ===================================================
      // ADMIN USER FLOW (regular update)
      // ===================================================
      print('👑 Admin user - keeping current status');
      
      // Admin keeps current status
      final updatedExpense = _expense!.copyWith(
        expenseId: widget.expenseId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: newAmount,
        programId: _selectedProgramId ?? _expense!.programId,
        category: _selectedCategory ?? _expense!.category,
        paymentMethod: _selectedPaymentMethod,
        expenseDate: _selectedDate,
        vendorName: _vendorController.text.trim().isNotEmpty 
            ? _vendorController.text.trim() 
            : null,
        referenceNumber: _referenceController.text.trim().isNotEmpty 
            ? _referenceController.text.trim() 
            : null,
        // Admin keeps current status
        status: _expense!.status,
        editReason: editReason,
        isEdited: true,
        lastEditedByUserId: currentUser.uid,
        lastEditedByUserName: currentUser.displayName ?? 'Admin',
        lastEditedAt: Timestamp.now(),
      );
      
      await expenseProvider.updateExpense(
        updatedExpense,
        editedByUserId: currentUser.uid,
        editedByUserName: currentUser.displayName ?? 'Admin',
        editReason: editReason,
      );
      
      widget.onSave(updatedExpense);
      
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Expense updated successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    // Navigate back
    if (mounted) Navigator.pop(context);
    
  } catch (e) {
    print('❌ Error in _saveChanges: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
        actions: [
          if (!_isLoading && !_hasError)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading expense',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchExpenseAndPrograms,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Expense ID info
                        Card(
                          color: Colors.grey[100],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.info, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Expense ID: ${widget.expenseId}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Original Amount Info
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Original Amount:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '₹${_expense!.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Program Selection Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Program *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedProgramId,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              items: _availablePrograms.map((program) {
                                return DropdownMenuItem<String>(
                                  value: program.programId,
                                  child: Text(program.title),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedProgramId = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a program';
                                }
                                return null;
                              },
                              hint: const Text('Select Program'),
                            ),
                            if (_availablePrograms.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'No active programs found in this community',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Title Field
                        CustomTextField(
                          label: 'Expense Title *',
                          controller: _titleController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter expense title';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Description Field
                        CustomTextField(
                          label: 'Description (Optional)',
                          controller: _descriptionController,
                          maxLines: 3,
                          hintText: 'Add expense details...',
                        ),

                        const SizedBox(height: 16),

                        // Amount Field
                        CustomTextField(
                          label: 'Amount *',
                          controller: _amountController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Category Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              items: _categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(_formatCategory(category)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedCategory = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select category';
                                }
                                return null;
                              },
                              hint: const Text('Select Category'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Payment Method Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Method *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedPaymentMethod,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              items: _paymentMethods.map((method) {
                                return DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(_formatPaymentMethod(method)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedPaymentMethod = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select payment method';
                                }
                                return null;
                              },
                              hint: const Text('Select Payment Method'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Date Selection
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expense Date *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey[400]!,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      DateFormat.yMMMMd().format(_selectedDate),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Vendor Name Field
                        CustomTextField(
                          label: 'Vendor Name (Optional)',
                          controller: _vendorController,
                          hintText: 'Enter vendor name...',
                        ),

                        const SizedBox(height: 16),

                        // Reference Number Field
                        CustomTextField(
                          label: 'Reference Number (Optional)',
                          controller: _referenceController,
                          hintText: 'e.g., Invoice #, Receipt #...',
                        ),

                        const SizedBox(height: 16),

                        // Edit Reason Field
                        CustomTextField(
                          label: 'Reason for Edit *',
                          controller: _editReasonController,
                          maxLines: 2,
                          hintText: 'Why are you making these changes?',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please provide a reason for editing';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Changes Summary
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Changes Summary',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildChangeItem(
                                  'Amount',
                                  '₹${_expense!.amount.toStringAsFixed(2)}',
                                  '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
                                ),
                                _buildChangeItem(
                                  'Title',
                                  _expense!.title,
                                  _titleController.text.trim(),
                                ),
                                _buildChangeItem(
                                  'Program',
                                  _getProgramNameById(_expense!.programId),
                                  _selectedProgramId != null
                                      ? _getProgramNameById(_selectedProgramId!)
                                      : _getProgramNameById(_expense!.programId),
                                ),
                                _buildChangeItem(
                                  'Category',
                                  _formatCategory(_expense!.category),
                                  _selectedCategory != null 
                                      ? _formatCategory(_selectedCategory!)
                                      : _formatCategory(_expense!.category),
                                ),
                                if (_descriptionController.text.trim() != _expense!.description)
                                  _buildChangeItem(
                                    'Description',
                                    _expense!.description,
                                    _descriptionController.text.trim(),
                                    isText: true,
                                  ),
                                if (_selectedPaymentMethod != _expense!.paymentMethod)
                                  _buildChangeItem(
                                    'Payment Method',
                                    _expense!.paymentMethod != null
                                        ? _formatPaymentMethod(_expense!.paymentMethod!)
                                        : 'Not set',
                                    _selectedPaymentMethod != null
                                        ? _formatPaymentMethod(_selectedPaymentMethod!)
                                        : 'Not set',
                                  ),
                                if (_selectedDate != _expense!.expenseDate)
                                  _buildChangeItem(
                                    'Date',
                                    DateFormat.yMMMMd().format(_expense!.expenseDate),
                                    DateFormat.yMMMMd().format(_selectedDate),
                                  ),
                                if (_vendorController.text.trim() != (_expense!.vendorName ?? ''))
                                  _buildChangeItem(
                                    'Vendor',
                                    _expense!.vendorName ?? 'None',
                                    _vendorController.text.trim(),
                                  ),
                                if (_referenceController.text.trim() != (_expense!.referenceNumber ?? ''))
                                  _buildChangeItem(
                                    'Reference',
                                    _expense!.referenceNumber ?? 'None',
                                    _referenceController.text.trim(),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  widget.onSave(null);
                                  Navigator.pop(context);
                                },
                                child: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveChanges,
                                child: const Text('Save Changes'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildChangeItem(String label, String oldValue, String newValue,
      {bool isText = false}) {
    final hasChanged = oldValue != newValue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oldValue,
                  style: TextStyle(
                    color: hasChanged ? Colors.red : Colors.grey[600],
                    decoration:
                        hasChanged ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (hasChanged)
                  Text(
                    '→ $newValue',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _editReasonController.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
}