import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/program_model.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../expenses/models/expense_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../auth/models/user_model.dart';
import '../../../../core/constants/app_colors.dart'; // Add this import

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
        // Expense Summary
        _buildExpenseSummary(context),
        
        const SizedBox(height: 0), // 8px gap
        
        // Search and Filter Bar
        _buildSearchFilterBar(context),
        
        const SizedBox(height: 0), // 8px gap
        
        // Expenses List
        Expanded(
          child: StreamBuilder<List<ExpenseModel>>(
            stream: Provider.of<ExpenseProvider>(context, listen: false)
                .streamProgramExpenses(widget.program.programId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary(context),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error,
                        color: AppColors.error(context),
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading expenses',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final expenses = snapshot.data ?? [];
              final filteredExpenses = _filterExpenses(expenses);

              if (filteredExpenses.isEmpty) {
                return _buildEmptyState(expenses.isEmpty, isAdmin, context);
              }

              return ListView.builder(
                itemCount: filteredExpenses.length,
                itemBuilder: (context, index) {
                  final expense = filteredExpenses[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0), // 8px gap between cards
                    child: _buildExpenseCard(expense, context, isAdmin),
                  );
                },
              );
            },
          ),
        ),

        // Add Expense Button (Admin Only) or Not Approved Message
        Padding(
          padding: const EdgeInsets.symmetric(horizontal:8, vertical: 16), // 8px padding
          child: Column(
            children: [
              if (currentUser != null && !currentUser.isApproved) 
                _buildNotApprovedMessage(context),
              
              if (isAdmin || (currentUser != null && currentUser.isApproved)) 
                _buildAddExpenseButton(context, isAdmin),
            ],
          ),
        ),
      ],
    );
  }

 Widget _buildExpenseCard(ExpenseModel expense, BuildContext context, bool isAdmin) {
  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isAdmin) {
              _showExpenseActions(expense, context);
            } else {
              _showExpenseDetails(expense, context);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              
              children: [
                
                // Leading icon
                Container(

                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(expense.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: _getCategoryColor(expense.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Description (if exists)
                      if (expense.description != null && expense.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            expense.description!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(expense.expenseDate)} • ${expense.category.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      if (!isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Paid by: ${expense.paidBy}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Trailing amount and status
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${expense.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(expense.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        expense.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      
      // Horizontal divider - Exactly like All Members screen
      Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border(context),
      ),
    ],
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

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ───────────────── Header ─────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Expenses Overview",
                      style: TextStyle(
                        color: AppColors.textCards(context).withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: AppColors.textCards(context),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${expenses.length} expenses',
                          style: TextStyle(
                            color: AppColors.textCards(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// ───────────────── APPROVED EXPENSES (Big Text) ─────────────────
            Text(
              "₹${approvedExpenses.toStringAsFixed(0)}",
              style: TextStyle(
                color: AppColors.textCards(context),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                "Approved Expenses",
                style: TextStyle(
                  color: AppColors.textCards(context).withOpacity(0.85),
                  fontSize: 11,
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// ───────────────── Stats Row ─────────────────
            Row(
              children: [
                _buildStatChip(
                  context,
                  icon: Icons.receipt,
                  label: "Total",
                  value: "₹${totalExpenses.toStringAsFixed(0)}",
                  color: AppColors.textCards(context),
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  context,
                  icon: Icons.pending,
                  label: "Pending",
                  value: "₹${pendingExpenses.toStringAsFixed(0)}",
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildSearchFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8), // 8px horizontal padding
      child: Row(
        children: [
          // Search Field
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search expenses...',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary(context),
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.border(context),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.border(context),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primary(context),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surface(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 13,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          const SizedBox(width: 8), // 8px gap
          
          // Status Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.border(context),
                ),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surface(context),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterStatus,
                  isExpanded: true,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondary(context),
                    size: 18,
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 12,
                  ),
                  dropdownColor: AppColors.card(context),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8), // 8px gap
          
          // Category Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.border(context),
                ),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surface(context),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterCategory,
                  isExpanded: true,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondary(context),
                    size: 18,
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 12,
                  ),
                  dropdownColor: AppColors.card(context),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Cat')),
                    ..._categories.map((category) => 
                      DropdownMenuItem(
                        value: category,
                        child: Text(category.substring(0, 3)),
                      )
                    ).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterCategory = value!;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddExpenseButton(BuildContext context, bool isAdmin) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Expense'),
        onPressed: () => _showAddExpenseDialog(context, isAdmin),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildNotApprovedMessage(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8), // 8px bottom margin
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info,
            color: Colors.orange.shade600,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your account is pending approval. You can view expenses but cannot manage them.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noExpenses, bool isAdmin, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noExpenses ? Icons.receipt_long_outlined : Icons.search_off,
            size: 60,
            color: AppColors.textTertiary(context),
          ),
          const SizedBox(height: 8),
          Text(
            noExpenses ? 'No Expenses Yet' : 'No Matching Expenses',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            noExpenses 
                ? (isAdmin ? 'Add your first expense to get started' : 'No expenses have been added yet')
                : 'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.textCards(context).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textCards(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textCards(context).withOpacity(0.85),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

void _showExpenseActions(ExpenseModel expense, BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Empty onTap to prevent inner taps from closing
            child: DraggableScrollableSheet(
              initialChildSize: .9,
              minChildSize: 0.25,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppColors.border(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Title
                        Text(
                          'Expense Actions',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // View Details
                        _buildActionTile(
                          context: context,
                          icon: Icons.visibility_outlined,
                          title: 'View Details',
                          color: AppColors.primary(context),
                          onTap: () {
                            Navigator.pop(context);
                            _showExpenseDetails(expense, context);
                          },
                        ),

                        // Status update options
                        if (expense.status == 'pending') ...[
                          _buildActionTile(
                            context: context,
                            icon: Icons.check_circle,
                            title: 'Approve Expense',
                            color: Colors.green,
                            onTap: () {
                              Navigator.pop(context);
                              _updateExpenseStatus(expense, 'approved', context);
                            },
                          ),
                          _buildActionTile(
                            context: context,
                            icon: Icons.cancel,
                            title: 'Reject Expense',
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              _updateExpenseStatus(expense, 'rejected', context);
                            },
                          ),
                        ],

                        if (expense.status != 'pending') ...[
                          if (expense.status == 'approved')
                            _buildActionTile(
                              context: context,
                              icon: Icons.cancel,
                              title: 'Mark as Rejected',
                              color: Colors.red,
                              onTap: () {
                                Navigator.pop(context);
                                _updateExpenseStatus(expense, 'rejected', context);
                              },
                            ),
                          if (expense.status == 'rejected')
                            _buildActionTile(
                              context: context,
                              icon: Icons.check_circle,
                              title: 'Mark as Approved',
                              color: Colors.green,
                              onTap: () {
                                Navigator.pop(context);
                                _updateExpenseStatus(expense, 'approved', context);
                              },
                            ),
                          _buildActionTile(
                            context: context,
                            icon: Icons.pending,
                            title: 'Mark as Pending',
                            color: Colors.orange,
                            onTap: () {
                              Navigator.pop(context);
                              _updateExpenseStatus(expense, 'pending', context);
                            },
                          ),
                        ],

                        // Delete Expense
                        _buildActionTile(
                          context: context,
                          icon: Icons.delete_outline,
                          title: 'Delete Expense',
                          color: AppColors.error(context),
                          isDestructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(expense, context);
                          },
                        ),

                        const SizedBox(height: 16),

                        // Cancel Button
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.card(context),
                                foregroundColor: AppColors.textPrimary(context),
                                side: BorderSide(color: AppColors.border(context)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDestructive 
                          ? AppColors.error(context) 
                          : AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary(context),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExpenseDetails(ExpenseModel expense, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          expense.title,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expense.description,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Amount', '₹ ${expense.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Category', expense.category.toUpperCase()),
              _buildDetailRow('Status', expense.status.toUpperCase()),
              _buildDetailRow('Date', DateFormat('dd MMM yyyy').format(expense.expenseDate)),
              _buildDetailRow('Paid By', expense.paidBy),
              _buildDetailRow('Created', DateFormat('dd MMM yyyy, hh:mm a').format(expense.createdAt.toDate())),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  void _updateExpenseStatus(ExpenseModel expense, String status, BuildContext context) async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      await expenseProvider.updateExpenseStatus(expense.expenseId, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense ${status}d successfully!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update expense: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

  void _showDeleteConfirmation(ExpenseModel expense, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Expense',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${expense.title}"? This action cannot be undone.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense(expense, context);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error(context),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(ExpenseModel expense, BuildContext context) async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      await expenseProvider.deleteExpense(expense.expenseId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Expense deleted successfully!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete expense: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

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
            backgroundColor: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Add New Expense',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 16,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Expense Title',
                      labelStyle: TextStyle(
                        color: AppColors.textSecondary(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary(context),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surface(context),
                    ),
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: TextStyle(
                        color: AppColors.textSecondary(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary(context),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surface(context),
                    ),
                    maxLines: 3,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: TextStyle(
                        color: AppColors.textSecondary(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary(context),
                          width: 2,
                        ),
                      ),
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: AppColors.surface(context),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(
                        color: AppColors.textSecondary(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary(context),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surface(context),
                    ),
                    dropdownColor: AppColors.card(context),
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Expense Date:',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                        child: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          style: TextStyle(
                            color: AppColors.primary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isAdmin)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.blue.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your expense will be submitted for admin approval',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 12,
                              ),
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
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Expense'),
              ),
            ],
          );
        },
      ),
    );
  }

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

      final status = isAdmin ? 'approved' : 'pending';

      final expense = ExpenseModel(
        expenseId: '',
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
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
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
            backgroundColor: AppColors.error(context),
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