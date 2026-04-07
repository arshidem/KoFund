import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/program_model.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../expenses/models/expense_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart'; // Add this import
import '../../../../core/constants/app_dimensions.dart'; // Add this import
import '../../../../core/services/network_service.dart'; // Add this import
import 'package:kofund/features/expenses/screens/edit_expense_screen.dart';
import 'package:kofund/core/skeleton/history_list_skeleton.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

// Add this class at the top of your file, after the imports
class ChangeEntry {
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  
  ChangeEntry({required this.fieldName, this.oldValue, this.newValue});
}
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

  final List<String> _paymentMethods = ['cash', 'upi'];
  String _filterPaymentMethod = 'all';

  void _onRefresh() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Refresh error: $e");
    }
  }

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

  // ✅ New Pinned Header Delegate
  Widget _buildPinnedSearchFilter(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverPinnedHeaderDelegate(
        minExtent: 64,
        maxExtent: 64,
        child: Container(
          color: AppColors.background(context),
          padding: const EdgeInsets.only(bottom: 8, top: 4, left: AppDimensions.screenPaddingHorizontal, right: AppDimensions.screenPaddingHorizontal),
          child: _buildSearchFilterBar(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: true);
    final isAdmin = _isAdmin(context);
    final currentUser = authProvider.user;
    
    return Stack(
      children: [
        Container(
          color: AppColors.background(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  _onRefresh();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
              ),

              // Expense Summary (Now scrollable)
              SliverToBoxAdapter(
                child: _buildExpenseSummary(context),
              ),
              
              // Search and Filter Bar (STICKY)
              _buildPinnedSearchFilter(context),
              
              // Expenses List
              StreamBuilder<List<ExpenseModel>>(
                stream: Provider.of<ExpenseProvider>(context, listen: false)
                    .streamProgramExpenses(widget.program.programId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 400,
                        child: HistoryListSkeleton(isDarkMode: Theme.of(context).brightness == Brightness.dark),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: _buildErrorState(snapshot.error, context),
                    );
                  }

                  final expenses = snapshot.data ?? [];
                  final filteredExpenses = _filterExpenses(expenses);

                  if (filteredExpenses.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(expenses.isEmpty, isAdmin, context),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = filteredExpenses[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: _buildExpenseCard(expense, context, isAdmin),
                        );
                      },
                      childCount: filteredExpenses.length,
                    ),
                  );
                },
              ),
              
              // Not Approved Message
              if (currentUser != null && !currentUser.isApproved)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: _buildNotApprovedMessage(context),
                  ),
                ),
              
              const SliverToBoxAdapter(
                child: SizedBox(height: 88),
              ),
            ],
          ),
        ),

      // Floating Add Button (stays same)
      if (isAdmin || (currentUser != null && currentUser.isApproved))
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddExpenseDialog(context, isAdmin),
            backgroundColor: AppColors.primary(context),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            elevation: 4,
            child: const Icon(Icons.add),
          ),
        ),
    ],
  );
}
Widget _buildErrorState(dynamic error, BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
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
            '$error',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
Widget _buildExpenseCard(ExpenseModel expense, BuildContext context, bool isAdmin) {
  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showExpenseDetails(expense, context);
          },
          child: Container(
                                                                 decoration: BoxDecoration(
  
    ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Icon column (fixed width)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(expense.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: _getCategoryColor(expense.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 2. Middle column: Title, date, category, paid by (expands)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(height: 2),
                      
                      if (expense.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            expense.description,
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
                      
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Paid by: ${expense.paidByName}',
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
                
                // 3. Right column: Amount, status, three-dot menu (all in one row)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Amount and status in a column
                
                    
               
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
                         // Three-dot menu
                    if (isAdmin || (_isUserPaidBy(expense, context)))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildThreeDotMenu(expense, context, isAdmin),
                      ),
                      
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      
      Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border(context),
      ),
    ],
  );
}

// Helper to check if current user paid for the expense
bool _isUserPaidBy(ExpenseModel expense, BuildContext context) {
  final authProvider = context.read<AppAuthProvider>();
  final currentUser = authProvider.user;
  return currentUser?.uid == expense.paidBy;
}

// Three-dot menu widget
Widget _buildThreeDotMenu(ExpenseModel expense, BuildContext context, bool isAdmin) {
  return PopupMenuButton<String>(
    icon: Icon(
      Icons.more_vert,
      color: AppColors.textSecondary(context),
      size: 20,
    ),
    onSelected: (value) {
      _handleMenuSelection(value, expense, context, isAdmin);
    },
    itemBuilder: (BuildContext context) {
      final List<PopupMenuEntry<String>> menuItems = [];
      
      // Always show View Details
      menuItems.add(const PopupMenuItem<String>(
        value: 'view_details',
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 20),
            SizedBox(width: 8),
            Text('View Details'),
          ],
        ),
      ));
      
      // Only admins or the user who paid can edit
      if (isAdmin || _isUserPaidBy(expense, context)) {
        menuItems.add(const PopupMenuItem<String>(
          value: 'edit_expense',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 8),
              Text('Edit Expense'),
            ],
          ),
        ));
      }
      
      // Only admins can change status
      if (isAdmin) {
        menuItems.add(const PopupMenuDivider());
        
        // Add header for status changes
        menuItems.add(const PopupMenuItem<String>(
          value: 'status_header',
          enabled: false,
          child: Text(
            'Change Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ));
        
        // Status options as separate menu items
        if (expense.status != 'pending') {
          menuItems.add(PopupMenuItem<String>(
            value: 'pending',
            child: Row(
              children: [
                Icon(Icons.pending, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Mark as Pending'),
              ],
            ),
          ));
        }
        
        if (expense.status != 'approved') {
          menuItems.add(PopupMenuItem<String>(
            value: 'approved',
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Mark as Approved'),
              ],
            ),
          ));
        }
        
        if (expense.status != 'rejected') {
          menuItems.add(PopupMenuItem<String>(
            value: 'rejected',
            child: Row(
              children: [
                Icon(Icons.cancel, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Mark as Rejected'),
              ],
            ),
          ));
        }
      }
      
      // Only admins can delete
      if (isAdmin || _isUserPaidBy(expense, context))  {
        menuItems.add(const PopupMenuDivider());
        menuItems.add(const PopupMenuItem<String>(
          value: 'delete_expense',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Delete Expense', style: TextStyle(color: Colors.red)),
            ],
          ),
        ));
      }
      
      return menuItems;
    },
  );
}



// Handle menu selection
void _handleMenuSelection(String value, ExpenseModel expense, BuildContext context, bool isAdmin) {
  switch (value) {
    case 'view_details':
      _showExpenseDetails(expense, context);
      break;
    case 'edit_expense':
      _navigateToEditExpense(expense, context);
      break;
    case 'pending':
      _updateExpenseStatusWithHistory(expense, 'pending', context);
      break;
    case 'approved':
      _updateExpenseStatusWithHistory(expense, 'approved', context);
      break;
    case 'rejected':
      _updateExpenseStatusWithHistory(expense, 'rejected', context);
      break;
    case 'delete_expense':
      _showDeleteConfirmation(expense, context);
      break;
  }
}

// Navigate to edit expense screen
void _navigateToEditExpense(ExpenseModel expense, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditExpenseScreen(
        expenseId: expense.expenseId,
        onSave: (updatedExpense) {
          if (updatedExpense != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary(context).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
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
                          color: AppColors.textCards(context).withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "All Time Summary",
                        style: TextStyle(
                          color: AppColors.textCards(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
  
                  // Top-right icon + count (mirrors contributions card)
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: AppColors.textCards(context),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${expenses.length}',
                        style: TextStyle(
                          color: AppColors.textCards(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                    color: AppColors.textCards(context).withValues(alpha: 0.85),
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
        ),
      );
    },
  );
}

  Widget _buildSearchFilterBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.border(context).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.primary(context),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter Button
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(color: AppColors.border(context), width: 1),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.tune, color: AppColors.primary(context), size: 20),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              setState(() {
                if (value.startsWith('status:')) {
                  _filterStatus = value.substring(7);
                } else if (value.startsWith('cat:')) {
                  _filterCategory = value.substring(4);
                } else if (value.startsWith('pay:')) {
                  _filterPaymentMethod = value.substring(4);
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('Filter by Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              ),
              _buildFilterMenuItem('status:all', 'All Status', Icons.list_alt_rounded, isStatus: true, isPayment: false),
              _buildFilterMenuItem('status:approved', 'Approved', Icons.check_circle_outline_rounded, isStatus: true, isPayment: false),
              _buildFilterMenuItem('status:pending', 'Pending', Icons.pending_outlined, isStatus: true, isPayment: false),
              _buildFilterMenuItem('status:rejected', 'Rejected', Icons.cancel_outlined, isStatus: true, isPayment: false),
              
              const PopupMenuDivider(),
              
              const PopupMenuItem(
                enabled: false,
                child: Text('Filter by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              ),
              _buildFilterMenuItem('cat:all', 'All Categories', Icons.category_outlined, isStatus: false, isPayment: false),
              ..._categories.map((cat) => 
                _buildFilterMenuItem('cat:$cat', cat.substring(0,1).toUpperCase() + cat.substring(1), Icons.label_outline_rounded, isStatus: false, isPayment: false)
              ),

              const PopupMenuDivider(),

              const PopupMenuItem(
                enabled: false,
                child: Text('Filter by Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              ),
              _buildFilterMenuItem('pay:all', 'All Methods', Icons.payments_outlined, isStatus: false, isPayment: true),
              _buildFilterMenuItem('pay:cash', 'Cash', Icons.money, isStatus: false, isPayment: true),
              _buildFilterMenuItem('pay:upi', 'UPI', Icons.phone_android, isStatus: false, isPayment: true),
            ],
          ),
        ),
      ],
      ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(String value, String label, IconData icon, {required bool isStatus, required bool isPayment}) {
    String actualValue;
    if (isStatus) {
      actualValue = value.substring(7);
    } else if (isPayment) {
      actualValue = value.substring(4);
    } else {
      actualValue = value.substring(4);
    }

    bool isSelected;
    if (isStatus) {
      isSelected = _filterStatus == actualValue;
    } else if (isPayment) {
      isSelected = _filterPaymentMethod == actualValue;
    } else {
      isSelected = _filterCategory == actualValue;
    }
    
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.primary(context) : AppColors.textSecondary(context),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildAddExpenseButton(BuildContext context, bool isAdmin) {
  return Visibility(
    child: Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context, isAdmin),
        backgroundColor: AppColors.primary(context),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        elevation: 4,
        child: const Icon(Icons.add),
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
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
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
  return Container(
    padding: const EdgeInsets.all(20),
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
          color: AppColors.textCards(context).withValues(alpha: 0.15),
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
                    color: AppColors.textCards(context).withValues(alpha: 0.85),
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

    if (_filterPaymentMethod != 'all') {
      filtered = filtered.where((expense) => expense.paymentMethod == _filterPaymentMethod).toList();
    }

    return filtered;
  }



// ✅ PREMIUM EXPENSE DETAILS BOTTOM SHEET
void _showExpenseDetails(ExpenseModel expense, BuildContext context) {
  final authProvider = context.read<AppAuthProvider>();
  final currentUser = authProvider.user;
  final isAdmin = _isAdmin(context);
  
  // Check if current user can see edit history
  final canViewEditHistory = isAdmin || currentUser?.uid == expense.paidBy;
  
  // Get formatted edit history
  final formattedEditHistory = _getFormattedEditHistory(expense);
  final isEdited = expense.isEdited || formattedEditHistory.isNotEmpty;
  
  // Get changes description
  final changesDescription = _getExpenseChangesDescription(formattedEditHistory);
  
  debugPrint('🔍 DEBUG Expense Details:');
  debugPrint('  - isEdited: $isEdited');
  debugPrint('  - editHistory length: ${expense.editHistory.length}');
  debugPrint('  - formattedEditHistory length: ${formattedEditHistory.length}');
  debugPrint('  - canViewEditHistory: $canViewEditHistory (admin: $isAdmin, paidBy: ${currentUser?.uid == expense.paidBy})');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: const Color(0x66000000), // Semi-transparent black overlay
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping inside
          child: DraggableScrollableSheet(
            initialChildSize: isEdited ? 0.8 : 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.5, 0.75, 0.95],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0F1F1D)
                      : const Color(0xFFF8FDFC),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 32,
                      spreadRadius: 0,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border(context).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expense Details',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(context).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    DateFormat('EEEE, MMMM dd • hh:mm a').format(expense.createdAt.toDate()),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isEdited)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.withValues(alpha: 0.15),
                                    Colors.orange.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 16, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edited',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Amount Card - Premium Design
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.border(context),
                                  width: 0.6,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ───── AMOUNT ─────
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₹',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        expense.amount.toStringAsFixed(2),
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary(context),
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // ───── EXPENSE TITLE ─────
                                  Text(
                                    expense.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // ───── STATUS CHIP ─────
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(expense.status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _getStatusColor(expense.status).withValues(alpha: 0.3),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      expense.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _getStatusColor(expense.status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // ───── BASIC INFORMATION ─────
                            _buildSectionHeader(
                              context,
                              title: 'Basic Information',
                              icon: Icons.info_outline_rounded,
                            ),

                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.border(context),
                                  width: 0.6,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ───── CATEGORY ─────
                                  _buildInfoRowMinimal(
                                    context,
                                    icon: _getCategoryIcon(expense.category),
                                    label: 'Category',
                                    value: expense.category.toUpperCase(),
                                  ),

                                  const SizedBox(height: 12),
                                  Divider(
                                    height: 1,
                                    thickness: 0.6,
                                    color: AppColors.border(context),
                                  ),
                                  const SizedBox(height: 12),

                                  // ───── DESCRIPTION ─────
                                  if (expense.description.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Description',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textTertiary(context),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          expense.description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: AppColors.textPrimary(context),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Divider(
                                          height: 1,
                                          thickness: 0.6,
                                          color: AppColors.border(context),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),

                                  // ───── PAID BY ─────
                                  _buildInfoRowMinimal(
                                    context,
                                    icon: Icons.person_rounded,
                                    label: 'Paid By',
                                    value: expense.paidByName,
                                  ),

                                  const SizedBox(height: 12),
                                  Divider(
                                    height: 1,
                                    thickness: 0.6,
                                    color: AppColors.border(context),
                                  ),
                                  const SizedBox(height: 12),

                                  // ───── EXPENSE DATE ─────
                                  _buildInfoRowMinimal(
                                    context,
                                    icon: Icons.calendar_today_rounded,
                                    label: 'Expense Date',
                                    value: DateFormat('dd MMM yyyy').format(expense.expenseDate),
                                  ),

                                  // ───── ADDITIONAL FIELDS (if available) ─────
                                  if (expense.vendorName?.isNotEmpty == true) ...[
                                    const SizedBox(height: 12),
                                    Divider(
                                      height: 1,
                                      thickness: 0.6,
                                      color: AppColors.border(context),
                                    ),
                                    const SizedBox(height: 12),

                                    _buildInfoRowMinimal(
                                      context,
                                      icon: Icons.store_rounded,
                                      label: 'Vendor',
                                      value: expense.vendorName!,
                                    ),
                                  ],

                                  if (expense.paymentMethod?.isNotEmpty == true) ...[
                                    const SizedBox(height: 12),
                                    Divider(
                                      height: 1,
                                      thickness: 0.6,
                                      color: AppColors.border(context),
                                    ),
                                    const SizedBox(height: 12),

                                    _buildInfoRowMinimal(
                                      context,
                                      icon: Icons.payment_rounded,
                                      label: 'Payment Method',
                                      value: _formatPaymentMethod(expense.paymentMethod!),
                                    ),
                                  ],

      
                                ],
                              ),
                            ),
                            
                            // ───── EDIT HISTORY SECTION ─────
                            if (isEdited && canViewEditHistory && formattedEditHistory.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 24),

                                  Divider(
                                    thickness: 0.6,
                                    color: AppColors.border(context),
                                  ),

                                  const SizedBox(height: 20),

                                  // ───── HEADER ─────
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.history_rounded,
                                          size: 18,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Edit History',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Most recent changes first',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textTertiary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // ───── CHANGE SUMMARY ─────
                                  if (changesDescription.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface(context),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.border(context),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        changesDescription,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.55,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                    ),
                                  ],

                                  // ───── EDIT HISTORY ITEMS ─────
                                  if (formattedEditHistory.isNotEmpty) ...[
                                    const SizedBox(height: 24),

                                    for (final edit in formattedEditHistory)
                                      _buildExpenseEditHistoryItem(context, edit),
                                  ],
                                ],
                              ),
                            
                            // Bottom Padding
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom Action Buttons - STATUS MANAGEMENT
                   // Replace the entire bottom action buttons section with this:

// Bottom Action Buttons - ONLY CLOSE BUTTON
Container(
  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
  decoration: BoxDecoration(
    color: AppColors.surface(context),
    border: Border(
      top: BorderSide(
        color: AppColors.border(context),
        width: 1.5,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, -4),
      ),
    ],
  ),
  child: Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary(context),
            side: BorderSide(
              color: AppColors.border(context),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
          child: const Text(
            'Close',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  ),
),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

// Helper method to update expense status WITH edit history
Future<void> _updateExpenseStatusWithHistory(
  ExpenseModel expense, 
  String newStatus, 
  BuildContext context,
  {String? reason}
) async {
  try {
    final authProvider = context.read<AppAuthProvider>();
    final currentUser = authProvider.user;
    final expenseProvider = context.read<ExpenseProvider>();
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to update status')),
      );
      return;
    }

    // Create edit record for status change
    final editRecord = {
      'editedAt': Timestamp.now(),
      'editedByUserId': currentUser.uid,
      'editedByUserName': currentUser.displayName ?? currentUser.email ?? 'Admin',
      'changes': {
        'status': {
          'old': expense.status,
          'new': newStatus,
        }
      },
      'reason': reason ?? 'Status changed',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Get existing edit history and add new record
    final existingEditHistory = expense.editHistory;
    final updatedEditHistory = List<Map<String, dynamic>>.from(existingEditHistory)
      ..add(editRecord);

    // Update expense with new status AND edit history
    await expenseProvider.updateExpenseWithHistory(
      expense.expenseId,
      {
        'status': newStatus,
        'isEdited': true,
        'lastEditedByUserId': currentUser.uid,
        'lastEditedByUserName': currentUser.displayName ?? currentUser.email ?? 'Admin',
        'lastEditedAt': Timestamp.now(),
        'editReason': reason ?? 'Status changed',
        'editHistory': updatedEditHistory,
      },
    );

    // Close the bottom sheet
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expense marked as $newStatus!'),
        backgroundColor: _getStatusColor(newStatus),
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

// Helper method to get formatted edit history
List<Map<String, dynamic>> _getFormattedEditHistory(ExpenseModel expense) {
  final editHistory = expense.editHistory;
  
  if (editHistory.isEmpty) return [];
  
  // Sort by timestamp (newest first)
  final sortedHistory = List<Map<String, dynamic>>.from(editHistory)
    ..sort((a, b) {
      final timeA = a['timestamp'] ?? 0;
      final timeB = b['timestamp'] ?? 0;
      return timeB.compareTo(timeA);
    });
  
  return sortedHistory;
}

// Helper method to get changes description
String _getExpenseChangesDescription(List<Map<String, dynamic>> editHistory) {
  if (editHistory.isEmpty) return '';
  
  // Get the latest edit record
  final latestEdit = editHistory.isNotEmpty ? editHistory.first : null;
  if (latestEdit == null) return '';
  
  final changes = latestEdit['changes'] as Map<String, dynamic>?;
  if (changes == null || changes.isEmpty) return '';
  
  final List<String> changeDescriptions = [];
  
  changes.forEach((field, changeData) {
    final oldValue = changeData is Map ? changeData['old']?.toString() : null;
    final newValue = changeData is Map ? changeData['new']?.toString() : changeData?.toString();
    final fieldName = _getExpenseFieldDisplayName(field);
    
    if (oldValue != null && newValue != null) {
      changeDescriptions.add('$fieldName: $oldValue → $newValue');
    } else if (newValue != null) {
      changeDescriptions.add('$fieldName changed to $newValue');
    }
  });
  
  return changeDescriptions.join(', ');
}

// Build edit history item widget for expenses
Widget _buildExpenseEditHistoryItem(BuildContext context, Map<String, dynamic> edit) {
  final editedAt = edit['editedAt'] != null 
      ? (edit['editedAt'] as Timestamp).toDate()
      : null;
  final editedBy = edit['editedByUserName'] ?? 
                 edit['editedByUserId'] ?? 
                 'Unknown';
  final changes = edit['changes'] ?? {};
  final reason = edit['reason'];

  // Get change entries
  final changeEntries = _getExpenseChangeEntries(changes);

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
    color: AppColors.surface(context),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppColors.border(context),
      width: 0.6,
    ),
  ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───── DATE + USER ─────
        Row(
          children: [
            Text(
              editedAt != null
                  ? DateFormat('MMM dd, yyyy hh:mm a').format(editedAt)
                  : 'Unknown time',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary(context),
              ),
            ),
            const Spacer(),
            Text(
              'By: $editedBy',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ───── CHANGE LINES ─────
        if (changeEntries.isNotEmpty)
          for (final change in changeEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary(context),
                  ),
                  children: [
                    const TextSpan(text: '•  '),
                    TextSpan(
                      text: '${change.fieldName}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (change.oldValue != null)
                      TextSpan(
                        text: change.oldValue,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (change.oldValue != null && change.newValue != null)
                      const TextSpan(text: '  →  '),
                    if (change.newValue != null)
                      const TextSpan(text: ''),
                    if (change.newValue != null)
                      TextSpan(
                        text: change.newValue,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),

        // ───── REASON ─────
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary(context),
            ),
          ),
        ],
      ],
    ),
  );
}

// Helper method to get expense change entries
List<ChangeEntry> _getExpenseChangeEntries(Map<String, dynamic> changes) {
  final entries = <ChangeEntry>[];
  
  changes.forEach((key, value) {
    final fieldName = _getExpenseFieldDisplayName(key);
    
    String? oldValue;
    String? newValue;
    
    if (value is Map<String, dynamic>) {
      oldValue = value['old']?.toString();
      newValue = value['new']?.toString();
    } else if (value is String) {
      newValue = value;
    }
    
    entries.add(ChangeEntry(
      fieldName: fieldName, 
      oldValue: oldValue, 
      newValue: newValue
    ));
  });
  
  return entries;
}

// Helper method for expense field display names
String _getExpenseFieldDisplayName(String field) {
  final displayNames = {
    'amount': 'Amount',
    'title': 'Title',
    'description': 'Description',
    'category': 'Category',
    'status': 'Status',
    'paidBy': 'Paid By',
    'expenseDate': 'Expense Date',
    'vendorName': 'Vendor',
    'paymentMethod': 'Payment Method',
    'referenceNumber': 'Reference No.',
    'receiptUrl': 'Receipt',
  };
  
  if (displayNames.containsKey(field)) {
    return displayNames[field]!;
  }
  
  // Convert camelCase to Title Case
  final buffer = StringBuffer();
  for (int i = 0; i < field.length; i++) {
    if (i > 0 && field[i] == field[i].toUpperCase()) {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? field[i].toUpperCase() : field[i]);
  }
  
  return buffer.toString();
}

// Helper method to build minimal info rows
Widget _buildInfoRowMinimal(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(
        icon,
        size: 16,
        color: AppColors.textTertiary(context),
      ),
      const SizedBox(width: 10),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// Helper method for section headers
Widget _buildSectionHeader(BuildContext context, {required String title, required IconData icon}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: AppColors.primary(context),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}

// Add this method for payment method formatting
String _formatPaymentMethod(String method) {
  switch (method.toLowerCase()) {
    case 'cash': return 'Cash';
    case 'upi': return 'UPI';
    default: return method;
  }
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
      if (!mounted) return;
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
  void _showDeleteConfirmation(ExpenseModel expense, BuildContext context) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Delete Expense?',
      message: 'Are you sure you want to delete "${expense.title}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (result == true) {
      _deleteExpense(expense, context);
    }
  }

  void _deleteExpense(ExpenseModel expense, BuildContext context) async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      await expenseProvider.deleteExpense(expense.expenseId);
      if (!mounted) return;
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
  String selectedPaymentMethod = _paymentMethods.first;
  DateTime selectedDate = DateTime.now();

  // Input formatters
  final titleInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9\s]'), // Only allow letters, numbers, and spaces
  );

  // Variables for error messages
  String? titleError;
  String? amountError;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        // Function to reset errors when user types
        void clearTitleError() {
          if (titleError != null) {
            setDialogState(() {
              titleError = null;
            });
          }
        }

        void clearAmountError() {
          if (amountError != null) {
            setDialogState(() {
              amountError = null;
            });
          }
        }

        // Validation function
        Future<void> validateAndSubmit(bool isOnline) async {
          // Check network first
          if (!isOnline) {
            setDialogState(() {
              titleError = 'No internet connection';
            });
            return;
          }

          // Reset errors
          setDialogState(() {
            titleError = null;
            amountError = null;
          });

          bool hasError = false;

          // Validate title
          if (titleController.text.isEmpty) {
            setDialogState(() {
              titleError = 'Please enter expense title';
              hasError = true;
            });
          } else if (titleController.text.length < 3) {
            setDialogState(() {
              titleError = 'Title must be at least 3 characters';
              hasError = true;
            });
          }

          // Validate amount
          if (amountController.text.isEmpty) {
            setDialogState(() {
              amountError = 'Please enter amount';
              hasError = true;
            });
          } else {
            final amount = double.tryParse(amountController.text);
            if (amount == null || amount <= 0) {
              setDialogState(() {
                amountError = 'Please enter a valid amount greater than 0';
                hasError = true;
              });
            } else if (amount > 9999999.99) {
              setDialogState(() {
                amountError = 'Amount cannot exceed ₹ 99,99,999.99';
                hasError = true;
              });
            }
          }

          // If no errors, proceed
          if (!hasError) {
            try {
              await _createExpense(
                context: context,
                title: titleController.text.trim(),
                description: descriptionController.text.trim(),
                amount: double.parse(amountController.text),
                category: selectedCategory,
                paymentMethod: selectedPaymentMethod,
                expenseDate: selectedDate,
                isAdmin: isAdmin,
              );

              Navigator.pop(context);
            } catch (e) {
              setDialogState(() {
                amountError = 'Failed to add expense: $e';
              });
            }
          }
        }

return AlertDialog(
  backgroundColor: AppColors.card(context),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  contentPadding: const EdgeInsets.all(20),
  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
  title: Text(
    'Add New Expense',
    style: TextStyle(
      color: AppColors.textPrimary(context),
      fontSize: 16,
    ),
  ),
  content: SizedBox(
    width: MediaQuery.of(context).size.width * 0.8, // 70% width - good choice!
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title field with error
          TextField(
            controller: titleController,
            inputFormatters: [titleInputFormatter],
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'Expense Title *',
              labelStyle: TextStyle(
                color: AppColors.textSecondary(context),
              ),
              errorText: titleError, // Make sure you add this for inline validation
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                borderSide: BorderSide(
                  color: AppColors.border(context),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                borderSide: BorderSide(
                  color: AppColors.border(context),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                borderSide: BorderSide(
                  color: AppColors.primary(context),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface(context),
              counterText: '${titleController.text.length}/50',
              counterStyle: TextStyle(
                fontSize: 11,
                color: titleController.text.length > 45 
                    ? Colors.orange 
                    : AppColors.textTertiary(context),
              ),
            ),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 13,
            ),
            onChanged: (value) {
              setDialogState(() {}); // Update counter
              clearTitleError(); // Clear error when typing
            },
          ),
                const SizedBox(height: 12),

                // Description Field
                TextField(
                  controller: descriptionController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.primary(context),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.surface(context),
                    counterText: '${descriptionController.text.length}/200',
                    counterStyle: TextStyle(
                      fontSize: 11,
                      color: descriptionController.text.length > 190 
                          ? Colors.orange 
                          : AppColors.textTertiary(context),
                    ),
                  ),
                  maxLines: 3,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 13,
                  ),
                  onChanged: (value) {
                    setDialogState(() {}); // Update counter
                  },
                ),
                const SizedBox(height: 12),

                // Amount field with error
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount (₹) *',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    errorText: amountError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.primary(context),
                        width: 2,
                      ),
                    ),
                    prefixText: '₹ ',
                    filled: true,
                    fillColor: AppColors.surface(context),
                    counterText: 'Max: 10 digits',
                    counterStyle: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary(context),
                    ),
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 13,
                  ),
                  onChanged: (value) {
                    clearAmountError();
                  },
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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

                // Payment Method Dropdown
                DropdownButtonFormField<String>(
                  value: selectedPaymentMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method *',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      borderSide: BorderSide(
                        color: AppColors.border(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
                  items: _paymentMethods.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPaymentMethod = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Date Picker
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

                // Info message for non-admin users
                if (!isAdmin)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),  
                    borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
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

                // Network status and submit button
                FutureBuilder<bool>(
                  future: NetworkService().isConnected,
                        builder: (context, snapshot) {
  if (snapshot.connectionState == ConnectionState.waiting) {
    // Use skeleton loader instead of spinner
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return HistoryListSkeleton(isDarkMode: isDarkMode);
  }

                    final bool isOnline = snapshot.data ?? true;

                    return StreamBuilder<bool>(
                      stream: NetworkService().onConnectionChanged,
                      initialData: isOnline,
                      builder: (context, streamSnapshot) {
                        final bool currentIsOnline = streamSnapshot.data ?? isOnline;

                        return Column(
                          children: [
                            if (!currentIsOnline)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.wifi_off,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'No internet connection.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
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
            FutureBuilder<bool>(
              future: NetworkService().isConnected,
              builder: (context, snapshot) {
                final bool isOnline = snapshot.data ?? true;

                return StreamBuilder<bool>(
                  stream: NetworkService().onConnectionChanged,
                  initialData: isOnline,
                  builder: (context, streamSnapshot) {
                    final bool currentIsOnline = streamSnapshot.data ?? isOnline;

                    return ElevatedButton(
                      onPressed: currentIsOnline
                          ? () => validateAndSubmit(currentIsOnline)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentIsOnline
                            ? AppColors.primary(context)
                            : Colors.grey[600],
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white70,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentIsOnline ? Icons.add : Icons.wifi_off,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentIsOnline ? 'Add Expense' : 'Offline',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
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
  required String paymentMethod,
  required DateTime expenseDate,
  required bool isAdmin,
}) async {
  try {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final currentUser = authProvider.user;

    // Check if user is logged in
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add expenses')),
      );
      return;
    }

    final status = isAdmin ? 'approved' : 'pending';

    // ✅ FIX: Get user display name from UserModel
    String getUserDisplayName() {
      // First try displayName
      if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        return currentUser.displayName!;
      }
      
      // Then try email (extract name part)
      if (currentUser.email.isNotEmpty) {
        final emailParts = currentUser.email.split('@');
        if (emailParts.isNotEmpty) {
          return emailParts[0]; // Name before @
        }
      }
      
      // Fallback: User + first 6 chars of UID
      return 'User ${currentUser.uid.substring(0, 6)}';
    }

    final expense = ExpenseModel(
      expenseId: '',
      programId: widget.program.programId,
      communityId: widget.program.communityId,
      title: title,
      description: description,
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      paidBy: currentUser.uid, // User ID
      paidByName: getUserDisplayName(), // ✅ FIXED: Pass String, not UserModel
      expenseDate: expenseDate,
      status: status,
      createdAt: Timestamp.now(),

    );

    await expenseProvider.createExpense(expense);
    if (!mounted) return;

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

class _SliverPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _SliverPinnedHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _SliverPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.maxExtent != maxExtent ||
        oldDelegate.minExtent != minExtent;
  }
}

