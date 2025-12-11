import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/program_model.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../expenses/models/expense_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../auth/models/user_model.dart';

class ProgramExpensesTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramExpensesTab({super.key, required this.program});

  @override
  State<ProgramExpensesTab> createState() => _ProgramExpensesTabState();
}

class _ProgramExpensesTabState extends State<ProgramExpensesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all';
  String _filterCategory = 'all';

  final List<String> _categories = [
    'food',
    'transport',
    'venue',
    'materials',
    'decorations',
    'other'
  ];

  // ✅ Check if current user is admin
  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    
    if (currentUser == null) return false;
    
    // 1. Program creator is always admin
    if (currentUser.uid == widget.program.createdBy) {
      return true;
    }
    
    // 2. User with 'admin' role
    if (currentUser.role == 'admin') {
      return true;
    }
    
    // 3. User with isAdmin flag and approved
    if (currentUser.isAdmin == true && currentUser.isApproved == true) {
      return true;
    }
    
    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: true);
    final isAdmin = _isAdmin(context);
    final currentUser = authProvider.user;
    
    return Column(
      children: [
        // Expense Summary Cards
        _buildExpenseSummary(context),
        
        // Search and Filter Bar
        _buildSearchFilterBar(),
        
        // Expenses List
        Expanded(
          child: StreamBuilder<List<ExpenseModel>>(
            stream: Provider.of<ExpenseProvider>(context, listen: false)
                .streamProgramExpenses(widget.program.programId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final expenses = snapshot.data ?? [];
              final filteredExpenses = _filterExpenses(expenses);

              if (filteredExpenses.isEmpty) {
                return _buildEmptyState(expenses.isEmpty, isAdmin);
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredExpenses.length,
                itemBuilder: (context, index) {
                  final expense = filteredExpenses[index];
                  return _buildExpenseCard(expense, context, isAdmin);
                },
              );
            },
          ),
        ),

        // Add Expense Button (Admin Only)
        if (isAdmin || (currentUser != null && currentUser.isApproved)) 
          _buildAddExpenseButton(context, isAdmin),
        
        // Show message if user is not approved
        if (currentUser != null && !currentUser.isApproved) 
          _buildNotApprovedMessage(),
      ],
    );
  }

  Widget _buildExpenseCard(ExpenseModel expense, BuildContext context, bool isAdmin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getCategoryColor(expense.category).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(expense.category),
            color: _getCategoryColor(expense.category),
          ),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.description),
            Text(
              '${DateFormat('MMM dd, yyyy').format(expense.expenseDate)} • ${expense.category.toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (!isAdmin)
              Text(
                'Paid by: ${expense.paidBy}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹ ${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                expense.status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _getStatusColor(expense.status),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        onTap: () {
          // For admin: show actions menu, for users: show view details directly
          if (isAdmin) {
            _showExpenseActions(expense, context);
          } else {
            _showExpenseDetails(expense, context);
          }
        },
      ),
    );
  }

  Widget _buildExpenseSummary(BuildContext context) {
    return StreamBuilder<List<ExpenseModel>>(
      stream: Provider.of<ExpenseProvider>(context, listen: false)
          .streamProgramExpenses(widget.program.programId),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? [];
        final totalExpenses = expenses.fold(0.0, (sum, expense) => sum + expense.amount);
        final approvedExpenses = expenses.where((e) => e.status == 'approved').fold(0.0, (sum, expense) => sum + expense.amount);
        final pendingExpenses = expenses.where((e) => e.status == 'pending').fold(0.0, (sum, expense) => sum + expense.amount);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('₹ ${totalExpenses.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Approved', '₹ ${approvedExpenses.toStringAsFixed(2)}', Colors.green),
                          _buildMiniStat('Pending', '₹ ${pendingExpenses.toStringAsFixed(2)}', Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search expenses...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatusDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildCategoryDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
          onChanged: (value) => setState(() => _filterStatus = value!),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterCategory,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Categories')),
            ..._categories.map((category) => 
              DropdownMenuItem(
                value: category,
                child: Text(category.toUpperCase()),
              )
            ).toList(),
          ],
          onChanged: (value) => setState(() => _filterCategory = value!),
        ),
      ),
    );
  }

  Widget _buildAddExpenseButton(BuildContext context, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        onPressed: () => _showAddExpenseDialog(context, isAdmin),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
      ),
    );
  }

  Widget _buildNotApprovedMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your account is pending approval. You can view expenses but cannot manage them.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noExpenses, bool isAdmin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noExpenses ? Icons.receipt_long_outlined : Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            noExpenses ? 'No Expenses Yet' : 'No Matching Expenses',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            noExpenses ? (isAdmin ? 'Add your first expense to get started' : 'No expenses have been added yet') : 'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> expenses) {
    List<ExpenseModel> filtered = expenses;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((expense) =>
        expense.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        expense.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_filterStatus != 'all') {
      filtered = filtered.where((expense) => expense.status == _filterStatus).toList();
    }

    if (_filterCategory != 'all') {
      filtered = filtered.where((expense) => expense.category == _filterCategory).toList();
    }

    return filtered;
  }

  // ✅ UPDATED: Simplified actions - only status update and delete for admin
  void _showExpenseActions(ExpenseModel expense, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showExpenseDetails(expense, context);
              },
            ),
            // ✅ Status update options only for pending expenses
            if (expense.status == 'pending') ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Approve Expense'),
                onTap: () {
                  Navigator.pop(context);
                  _updateExpenseStatus(expense, 'approved', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Reject Expense'),
                onTap: () {
                  Navigator.pop(context);
                  _updateExpenseStatus(expense, 'rejected', context);
                },
              ),
              const Divider(),
            ],
            // ✅ Show current status options for approved/rejected expenses
            if (expense.status != 'pending') ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Current Status: ${expense.status.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              // ✅ Allow changing between approved and rejected
              if (expense.status == 'approved')
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.red),
                  title: const Text('Mark as Rejected'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateExpenseStatus(expense, 'rejected', context);
                  },
                ),
              if (expense.status == 'rejected')
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Mark as Approved'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateExpenseStatus(expense, 'approved', context);
                  },
                ),
              // ✅ Allow moving back to pending for review
              ListTile(
                leading: const Icon(Icons.pending, color: Colors.orange),
                title: const Text('Mark as Pending'),
                onTap: () {
                  Navigator.pop(context);
                  _updateExpenseStatus(expense, 'pending', context);
                },
              ),
              const Divider(),
            ],
            // ✅ Delete option
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Expense'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(expense, context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetails(ExpenseModel expense, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(expense.description, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              _buildDetailRow('Amount', '₹ ${expense.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Category', expense.category.toUpperCase()),
              _buildDetailRow('Status', expense.status.toUpperCase()),
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(expense.expenseDate)),
              _buildDetailRow('Paid By', expense.paidBy),
              _buildDetailRow('Created', DateFormat('MMM dd, yyyy').format(expense.createdAt.toDate())),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _updateExpenseStatus(ExpenseModel expense, String status, BuildContext context) async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      await expenseProvider.updateExpenseStatus(expense.expenseId, status);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense ${status}d successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update expense: $e')));
    }
  }

  void _showDeleteConfirmation(ExpenseModel expense, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense(expense, context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(ExpenseModel expense, BuildContext context) async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      await expenseProvider.deleteExpense(expense.expenseId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete expense: $e')));
    }
  }

  // ✅ ADD EXPENSE DIALOG - COMPLETE IMPLEMENTATION
  void _showAddExpenseDialog(BuildContext context, bool isAdmin) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String selectedCategory = _categories.first;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Expense Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Expense Date:'),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != selectedDate) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      ),
                    ],
                  ),
                  if (!isAdmin)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your expense will be submitted for admin approval',
                              style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty || 
                      amountController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  await _createExpense(
                    context: context,
                    title: titleController.text,
                    description: descriptionController.text,
                    amount: amount,
                    category: selectedCategory,
                    expenseDate: selectedDate,
                    isAdmin: isAdmin,
                  );

                  Navigator.pop(context);
                },
                child: const Text('Add Expense'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ CREATE EXPENSE METHOD
// ✅ CREATE EXPENSE METHOD - Updated with proper error handling
Future<void> _createExpense({
  required BuildContext context,
  required String title,
  required String description,
  required double amount,
  required String category,
  required DateTime expenseDate,
  required bool isAdmin,
}) async {
  try {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add expenses')),
      );
      return;
    }

    // Determine status based on user role
    final status = isAdmin ? 'approved' : 'pending';

    final expense = ExpenseModel(
      expenseId: '', // Will be generated by Firestore
      programId: widget.program.programId,
      communityId: widget.program.communityId,
      title: title,
      description: description,
      amount: amount,
      category: category,
      paidBy: currentUser.displayName ?? currentUser.email ?? 'Unknown User',
      expenseDate: expenseDate,
      status: status,
      createdAt: Timestamp.now(),
    );

    await expenseProvider.createExpense(expense);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAdmin 
            ? 'Expense added and approved successfully!' 
            : 'Expense submitted for admin approval!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // ✅ PROPER ERROR HANDLING - Check for program participation error
    if (e.toString().contains('must be a participant') || 
        e.toString().contains('program participation')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You must join this program before adding expenses'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add expense: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'transport': return Colors.blue;
      case 'venue': return Colors.purple;
      case 'materials': return Colors.teal;
      case 'decorations': return Colors.pink;
      default: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'venue': return Icons.location_city;
      case 'materials': return Icons.inventory;
      case 'decorations': return Icons.celebration;
      default: return Icons.receipt;
    }
  }
}