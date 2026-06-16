import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event_model.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../expenses/models/expense_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart'; // Add this import
import '../../../../core/constants/app_dimensions.dart'; // Add this import
import '../../../../core/services/network_service.dart';
import '../../providers/event_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/expenses/screens/edit_expense_screen.dart';
import 'package:kofund/core/skeleton/history_list_skeleton.dart';
import 'package:kofund/core/utils/dialog_helper.dart';

// Add this class at the top of your file, after the imports
class ChangeEntry {
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  
  ChangeEntry({required this.fieldName, this.oldValue, this.newValue});
}
class EventExpensesTab extends StatefulWidget {
  final EventModel event;
  final String? selectedMonth;

  const EventExpensesTab({
    super.key,
    required this.event,
    this.selectedMonth,
  });

  @override
  State<EventExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<EventExpensesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all';

  List<ExpenseModel>? _cachedExpenses;
  Map<String, dynamic>? _cachedStats;

  Stream<List<ExpenseModel>>? _expensesStream;
  Stream<Map<String, dynamic>>? _statsStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    
    if (widget.event.isMonthlyPayment) {
      final monthId = widget.selectedMonth ?? DateFormat('yyyy-MM').format(DateTime.now());
      _expensesStream = expenseProvider.streamMonthlyExpenses(
        widget.event.eventId,
        monthId,
        communityId: widget.event.communityId,
      );
    } else {
      _expensesStream = expenseProvider.streamEventExpenses(
        widget.event.eventId,
        communityId: widget.event.communityId,
      );
    }
    
    _statsStream = _getExpenseStatsStream(context);
  }

  @override
  void didUpdateWidget(covariant EventExpensesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      setState(() {
        _cachedExpenses = null; // Clear cache on month switch to avoid showing wrong empty state
        _cachedStats = null;    // Clear stats too for a fresh load
        _initStreams();
      });
    }
  }

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
    
    // 1. event createor is always admin
    if (currentUser.uid == widget.event.createdBy) {
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
    super.build(context);
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
                  HapticHelper.light();
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
                initialData: _cachedExpenses,
                stream: _expensesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    _cachedExpenses = snapshot.data;
                  }

                  // Show skeleton ONLY on very first load with no cache
                  if (snapshot.connectionState == ConnectionState.waiting && _cachedExpenses == null) {
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 400,
                        child: HistoryListSkeleton(isDarkMode: Theme.of(context).brightness == Brightness.dark),
                      ),
                    );
                  }

                  if (snapshot.hasError && _cachedExpenses == null) {
                    return SliverToBoxAdapter(
                      child: _buildErrorState(snapshot.error, context),
                    );
                  }

                  // Use cached or live data
                  final expenses = _cachedExpenses ?? snapshot.data ?? [];
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
          child: StreamBuilder<List<ExpenseModel>>(
            stream: _expensesStream,
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? [];
              final filteredExpenses = _filterExpenses(expenses);
              return Visibility(
                visible: expenses.isNotEmpty,
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
              );
            },
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary(context),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 2. Middle column: Ttitle, date, category, paid by (expands)
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
                        DateFormat('dd/MM/yyyy').format(expense.expenseDate),
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
                
                // 3. Right column: Amount, status, and consistently aligned menu
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                    const SizedBox(width: 4),
                    _buildThreeDotMenu(expense, context, isAdmin),
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
      color: AppColors.textTertiary(context),
      size: 22,
    ),
    offset: const Offset(0, 40),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 4,
    color: AppColors.card(context),
    onSelected: (value) {
      _handleMenuSelection(value, expense, context, isAdmin);
    },
    itemBuilder: (BuildContext context) {
      final List<PopupMenuEntry<String>> menuItems = [];
      
      // Always show View Details
      menuItems.add(_buildPopupMenuItem(
        value: 'view_details',
        icon: Icons.visibility_rounded,
        label: 'View Details',
        color: AppColors.primary(context),
      ));
      
      // Only admins or the user who paid can edit
      if (isAdmin || _isUserPaidBy(expense, context)) {
        menuItems.add(_buildPopupMenuItem(
          value: 'edit_expense',
          icon: Icons.edit_rounded,
          label: 'Edit Expense',
          color: AppColors.primary(context),
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
          menuItems.add(_buildPopupMenuItem(
            value: 'pending',
            icon: Icons.pending_rounded,
            label: 'Mark as Pending',
            color: Colors.orange,
          ));
        }
        
        if (expense.status != 'approved') {
          menuItems.add(_buildPopupMenuItem(
            value: 'approved',
            icon: Icons.check_circle_rounded,
            label: 'Mark as Approved',
            color: Colors.green,
          ));
        }
        
        if (expense.status != 'rejected') {
          menuItems.add(_buildPopupMenuItem(
            value: 'rejected',
            icon: Icons.cancel_rounded,
            label: 'Mark as Rejected',
            color: AppColors.error(context),
          ));
        }
      }
      
      // Only admins can delete
      if (isAdmin || _isUserPaidBy(expense, context))  {
        menuItems.add(const PopupMenuDivider());
        menuItems.add(_buildPopupMenuItem(
          value: 'delete_expense',
          icon: Icons.delete_outline_rounded,
          label: 'Delete Expense',
          color: AppColors.error(context),
        ));
      }
      
      return menuItems;
    },
  );
}

PopupMenuItem<String> _buildPopupMenuItem({
  required String value,
  required IconData icon,
  required String label,
  required Color color,
}) {
  return PopupMenuItem<String>(
    value: value,
    height: 44,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    ),
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
            SnackbarHelper.showSuccess(context, 'Expense updated successfully');
          }
        },
      ),
    ),
  );
}

Widget _buildExpenseSummary(BuildContext context) {
  return StreamBuilder<Map<String, dynamic>>(
    initialData: _cachedStats,
    stream: _statsStream,
    builder: (context, snapshot) {
      // Smart-cache: only overwrite if new data has meaningful values
      if (snapshot.hasData) {
        _cachedStats = snapshot.data;
      }
      
      // Show shimmer only on first load when no cache exists
      if (snapshot.connectionState == ConnectionState.waiting && _cachedStats == null) {
        return _buildShimmerStats(context);
      }

      // Use cached data if available (works offline); fall back to empty
      final data = _cachedStats ?? snapshot.data ?? {
        'totalExpenses': 0.0,
        'expenses': 0.0,
        'totalCollected': 0.0,
        'collected': 0.0,
      };

      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      
      return StreamBuilder<List<ExpenseModel>>(
        stream: _expensesStream,
        builder: (context, expSnapshot) {
          final expenses = expSnapshot.data ?? _cachedExpenses ?? [];
          
          // Calculate stats locally for instant reflection
          double totalExpenses = 0.0;
          double approvedExpenses = 0.0;
          double pendingExpenses = 0.0;
          
          for (var exp in expenses) {
            totalExpenses += exp.amount;
            if (exp.status == 'approved') {
              approvedExpenses += exp.amount;
            } else if (exp.status == 'pending') {
              pendingExpenses += exp.amount;
            }
          }

          // Fallback to summary data if list is empty but summary has data (e.g. initial load)
          if (expenses.isEmpty && (data['totalExpenses'] ?? 0.0) > 0) {
            totalExpenses = (data['totalExpenses'] ?? data['expenses'] ?? 0.0).toDouble();
            approvedExpenses = totalExpenses;
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A2E2E), Color(0xFF0D1B1A)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00C6A2), Color(0xFF00E3C3)],
                      ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withValues(alpha: 0.3) 
                        : const Color(0xFF00C6A2).withValues(alpha: 0.25),
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
                            "EXPENSES OVERVIEW",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Summary",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      // Top-right icon + count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${expenses.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      
                  const SizedBox(height: 16),
      
                  /// ───────────────── APPROVED EXPENSES (Big Text) ─────────────────
                  Text(
                    "₹${approvedExpenses.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "Approved & Verified",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
                        label: "TOTAL",
                        value: "₹${totalExpenses.toStringAsFixed(0)}",
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        context,
                        icon: Icons.pending_rounded,
                        label: "PENDING",
                        value: "₹${pendingExpenses.toStringAsFixed(0)}",
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      );
    },
  );
}

Stream<Map<String, dynamic>> _getExpenseStatsStream(BuildContext context) {
  final eventProvider = Provider.of<EventProvider>(context, listen: false);
  
  if (widget.event.isMonthlyPayment) {
    final monthId = widget.selectedMonth ?? DateFormat('yyyy-MM').format(DateTime.now());
    return eventProvider.streamMonthlyFinancialSummary(
      widget.event.eventId,
      monthId,
      communityId: widget.event.communityId,
    );
  } else {
    return eventProvider.streamFinancialSummary(
      widget.event.eventId,
      communityId: widget.event.communityId,
    );
  }
}

  Widget _buildSearchFilterBar(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColorVal = isDark ? Colors.white70 : Colors.black;
    final Color filterIconColorVal = isDark ? Colors.white : Colors.black;

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
                    color: iconColorVal,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticHelper.light();
                  _showFilterBottomSheet(context);
                },
                child: Center(
                  child: Icon(Icons.tune, color: filterIconColorVal, size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildFilterColumn(String title, List<Widget> children) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...children,
                  ],
                ),
              );
            }

            Widget buildFilterItem(String label, IconData icon, bool isSelected, VoidCallback onTap) {
              return InkWell(
                onTap: () {
                  onTap();
                  HapticHelper.selection();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary(context).withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? AppColors.primary(context) : AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Expenses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _filterStatus = 'all';
                          });
                          setState(() {});
                          HapticHelper.medium();
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(color: AppColors.primary(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                   Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'STATUS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            buildFilterItem('All', Icons.list_alt_rounded, _filterStatus == 'all', () {
                              setSheetState(() => _filterStatus = 'all');
                              setState(() {});
                            }),
                            buildFilterItem('Approved', Icons.check_circle_outline_rounded, _filterStatus == 'approved', () {
                              setSheetState(() => _filterStatus = 'approved');
                              setState(() {});
                            }),
                            buildFilterItem('Pending', Icons.pending_outlined, _filterStatus == 'pending', () {
                              setSheetState(() => _filterStatus = 'pending');
                              setState(() {});
                            }),
                            buildFilterItem('Rejected', Icons.cancel_outlined, _filterStatus == 'rejected', () {
                              setSheetState(() => _filterStatus = 'rejected');
                              setState(() {});
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
  final authProvider = context.read<AppAuthProvider>();
  final currentUser = authProvider.user;
  final canAdd = isAdmin || (currentUser != null && currentUser.isApproved);

  return Container(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          noExpenses ? Icons.receipt_long_outlined : Icons.search_off,
          size: 80,
          color: AppColors.primary(context).withValues(alpha: 0.2),
        ),
        const SizedBox(height: 24),
        Text(
          noExpenses ? 'No Expenses Yet' : 'No Matching Expenses',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          noExpenses 
              ? (canAdd ? 'Add your first expense to get started' : 'No expenses have been added yet')
              : 'Try adjusting your search or filters',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 14,
          ),
        ),
        if (noExpenses && canAdd) ...[
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddExpenseDialog(context, isAdmin),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              elevation: 2,
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> expenses) {
    List<ExpenseModel> filtered = expenses;

    // Filter by shared month if it's a monthly event
    if (widget.event.isMonthlyPayment && widget.selectedMonth != null) {
      filtered = filtered.where((expense) => expense.monthId == widget.selectedMonth).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((expense) =>
        expense.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        expense.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_filterStatus != 'all') {
      filtered = filtered.where((expense) => expense.status == _filterStatus).toList();
    }

    return filtered;
  }



// ✅ PREMIUM EXPENSE DETAILS BOTTOM SHEET
void _showExpenseDetails(ExpenseModel expense, BuildContext context) {
  final authProvider = context.read<AppAuthProvider>();
  final currentUser = authProvider.user;
  final isAdmin = _isAdmin(context);
  final isCreator = currentUser?.uid == expense.paidBy;
  final canViewEditHistory = isAdmin || isCreator;
  
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
          onTap: () {}, // P closing when tapping inside
          child: DraggableScrollableSheet(
            initialChildSize: isEdited ? 0.65 : 0.55,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.5, 0.75, 0.95],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.background(context)
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
                                color: AppColors.card(context),
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
                                      color: AppColors.card(context),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border(context),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // ───── DATE ─────
                                        _buildInfoRowMinimal(
                                          context,
                                          icon: Icons.calendar_today_rounded,
                                          label: 'Date',
                                          value: DateFormat('MMM dd, yyyy').format(expense.expenseDate),
                                        ),

                                        if (expense.monthId != null) ...[
                                          const SizedBox(height: 12),
                                          Divider(
                                            height: 1,
                                            thickness: 0.6,
                                            color: AppColors.border(context),
                                          ),
                                          const SizedBox(height: 12),
                                          _buildInfoRowMinimal(
                                            context,
                                            icon: Icons.event_repeat_rounded,
                                            label: 'Month',
                                            value: _formatMonthId(expense.monthId!),
                                          ),
                                        ],

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

                                  // Removed paymentMethod section

      
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
                                        color: AppColors.card(context),
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
    color: AppColors.card(context),
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
      SnackbarHelper.showError(context, 'You must be logged in to update status');
      return;
    }

    // Create edit record for status change
    final editRecord = {
      'editedAt': Timestamp.now(),
      'editedByUserId': currentUser.uid,
      'editedByUserName': currentUser.displayName ?? currentUser.email,
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
        'lastEditedByUserName': currentUser.displayName ?? currentUser.email,
        'lastEditedAt': Timestamp.now(),
        'editReason': reason ?? 'Status changed',
        'editHistory': updatedEditHistory,
      },
    );
    
    SnackbarHelper.showSuccess(context, 'Expense marked as $newStatus!');
    
  } catch (e) {
    SnackbarHelper.showError(context, 'Failed to update expense: $e');
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
    color: AppColors.card(context),
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

// Helper method for expense field display nnames
String _getExpenseFieldDisplayName(String field) {
  final displayNames = {
    'amount': 'Amount',
    'title': 'Ttitle',
    'description': 'Description',
    'status': 'Status',
    'paidBy': 'Paid By',
    'expenseDate': 'Expense Date',
    'vendorName': 'Vendor',
    'referenceNumber': 'Reference No.',
    'receiptUrl': 'Receipt',
  };
  
  if (displayNames.containsKey(field)) {
    return displayNames[field]!;
  }
  
  // Convert cnamelCase to Ttitle Case
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
      SnackbarHelper.showSuccess(context, 'Expense ${status}eventId successfully!');
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to update expense: $e');
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
      SnackbarHelper.showSuccess(context, 'Expense deleted successfully!');
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to delete expense: $e');
    }
  }

  void _showAddExpenseDialog(BuildContext context, bool isAdmin) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController aamountController = TextEditingController();
    String? selectedMonthId = widget.selectedMonth ?? DateFormat('yyyy-MM').format(DateTime.now());

    final titleInputFormatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]'));
    String? titleError;
    String? aamountError;

    // Capture providers and theme colors using the stable screen context
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final stableSuccessColor = AppColors.success(context);
    final stableErrorColor = AppColors.error(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (stateContext, setBottomSheetState) {
          bool isLoading = false;
          bool isSubmitting = false; // Local lock for this specific submission attempt

          void clearTtitleError() {
            if (titleError != null) setBottomSheetState(() => titleError = null);
          }
          void clearAamountError() {
            if (aamountError != null) setBottomSheetState(() => aamountError = null);
          }

          Future<void> validateAndSubmit(bool isOnline) async {
            if (isSubmitting) return; // Immediate lock
            
            if (!isOnline) {
              setBottomSheetState(() => titleError = 'No internet connection');
              return;
            }

            bool hasError = false;
            if (titleController.text.isEmpty) {
              setBottomSheetState(() { titleError = 'Enter expense title'; hasError = true; });
            } else if (titleController.text.length < 3) {
              setBottomSheetState(() { titleError = 'Ttitle too short'; hasError = true; });
            }

            if (aamountController.text.isEmpty) {
              setBottomSheetState(() { aamountError = 'Enter amount'; hasError = true; });
            } else {
              final amount = double.tryParse(aamountController.text);
              if (amount == null || amount <= 0) {
                setBottomSheetState(() { aamountError = 'Invalid amount'; hasError = true; });
              }
            }

            if (hasError) {
              return;
            }

            // INSTANT CLOSE: Pop the modal immediately
            Navigator.pop(modalContext);

            // Trigger creation in background using outer context
            _createExpense(
              context: context,
              authProvider: authProvider,
              expenseProvider: expenseProvider,
              successColor: stableSuccessColor,
              errorColor: stableErrorColor,
              title: titleController.text.trim(),
              description: descriptionController.text.trim(),
              amount: double.parse(aamountController.text),
              expenseDate: DateTime.now(),
              isAdmin: isAdmin,
              monthId: widget.event.isMonthlyPayment ? selectedMonthId : null,
              isMonthlyExpense: widget.event.isMonthlyPayment,
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border(context).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Add New Expense',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Content
                  TextField(
                    controller: titleController,
                    inputFormatters: [titleInputFormatter],
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: 'Expense Ttitle *',
                      errorText: titleError,
                      hintText: 'What was this for?',
                      prefixIcon: const Icon(Icons.title_rounded, size: 20),
                      counterText: titleController.text.length >= 50 ? null : "",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      filled: true,
                      fillColor: AppColors.surface(context),
                    ),
                    onChanged: (_) {
                      setBottomSheetState(() {});
                      clearTtitleError();
                    },
                  ),
                  const SizedBox(height: 16),

                 TextField(
  controller: descriptionController,
  maxLength: 200,
  maxLines: 2,
  decoration: InputDecoration(
    labelText: 'Description (optional)',
    hintText: 'Additional details...',
    alignLabelWithHint: true, // ← This aligns label to the top
    prefixIcon: Padding(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 12, bottom: 40),
      child: Icon(
        Icons.description_rounded,
        size: 20,
      ),
    ),
    counterText: descriptionController.text.length >= 200 ? null : "",
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.border(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.border(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: AppColors.primary(context),
        width: 1.5,
      ),
    ),
    filled: true,
    fillColor: AppColors.surface(context),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 16,
    ),
  ),
  onChanged: (_) => setBottomSheetState(() {}),
),
                  const SizedBox(height: 16),

                  TextField(
                    controller: aamountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(
                      labelText: 'Amount (₹) *',
                      errorText: aamountError,
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      filled: true,
                      fillColor: AppColors.surface(context),
                    ),
                    onChanged: (_) => clearAamountError(),
                  ),
                  const SizedBox(height: 16),

                  if (widget.event.isMonthlyPayment) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Select Month',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        // Using the style from event_details_screen
                        _showMonthSelectorDialogForAdd(context, (monthId) {
                          setBottomSheetState(() {
                            selectedMonthId = monthId;
                          });
                        }, selectedMonthId ?? DateFormat('yyyy-MM').format(DateTime.now()));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary(context)),
                            const SizedBox(width: 12),
                            Text(
                              selectedMonthId != null 
                                  ? _formatMonthDisplay(selectedMonthId!) 
                                  : 'Select Month',
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary(context)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(modalContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<bool>(
                          future: NetworkService().isConnected,
                          builder: (fbContext, snapshot) {
                            final isOnline = snapshot.data ?? true;
                            return ElevatedButton(
                              onPressed: (isOnline && !isLoading) ? () => validateAndSubmit(isOnline) : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(context),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
                                elevation: 0,
                              ),
                              child: isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Add Expense'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

Future<bool> _createExpense({
  required BuildContext context,
  required AppAuthProvider authProvider,
  required ExpenseProvider expenseProvider,
  required Color successColor,
  required Color errorColor,
  required String title,
  required String description,
  required double amount,
  required DateTime expenseDate,
  required bool isAdmin,
  String? monthId,
  bool isMonthlyExpense = false,
}) async {
  try {
    final currentUser = authProvider.user;

    if (currentUser == null) {
      SnackbarHelper.showError(context, 'You must be logged in to add expenses');
      return false;
    }

    final status = isAdmin ? 'approved' : 'pending';

    String getUserDisplayName() {
      if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        return currentUser.displayName!;
      }
      if (currentUser.email.isNotEmpty) {
        final emailParts = currentUser.email.split('@');
        if (emailParts.isNotEmpty) return emailParts[0];
      }
      return 'User ${currentUser.uid.substring(0, 6)}';
    }

    final expense = ExpenseModel(
      expenseId: '',
      eventId: widget.event.eventId,
      communityId: widget.event.communityId,
      title: title,
      description: description,
      amount: amount,
      paidBy: currentUser.uid,
      paidByName: getUserDisplayName(),
      expenseDate: DateTime.now(),
      status: status,
      createdAt: Timestamp.now(),
      monthId: monthId,
      isMonthlyExpense: isMonthlyExpense,
    );

    await expenseProvider.createExpense(expense);
    
    // Show success snackbar
    SnackbarHelper.showSuccess(
      context,
      isAdmin 
        ? 'Expense added and approved successfully!' 
        : 'Expense submitted for admin approval!',
    );
    return true;
  } catch (e) {
    if (e.toString().contains('must be a participant')) {
      SnackbarHelper.showWarning(context, 'Join this event before adding expenses');
    } else {
      // Log error but don't crash the UI if it's just a SnackBar failure
      debugPrint('Error in _createExpense: $e');
      SnackbarHelper.showError(context, 'Failed to add expense: $e');
    }
    return false;
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

  // Helper methods for month formatting
  String _formatMonthId(String monthId) {
     try {
       final parts = monthId.split('-');
       final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
       return DateFormat('MMMM yyyy').format(date);
     } catch (e) {
       return monthId;
     }
  }

  String _formatMonthDisplay(String monthId) {
    try {
      final parts = monthId.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return monthId;
    }
  }

  String _getShortMonthName(int month) {
    return DateFormat('MMM').format(DateTime(2024, month));
  }

  void _showMonthSelectorDialogForAdd(BuildContext context, Function(String) onMonthSelected, String initialMonth) {
    int displayYear = int.parse(initialMonth.split('-')[0]);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Month',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textSecondary(context), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: AppColors.primary(context), size: 20),
                        onPressed: () => setDialogState(() => displayYear--),
                      ),
                      Text(
                        '$displayYear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: AppColors.primary(context), size: 20),
                        onPressed: () => setDialogState(() => displayYear++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final monthNumber = index + 1;
                    final monthIdString = '$displayYear-${monthNumber.toString().padLeft(2, '0')}';
                    final isSelected = monthIdString == initialMonth;
                    final isCurrentMonth = monthIdString == DateFormat('yyyy-MM').format(DateTime.now());

                    return GestureDetector(
                      onTap: () {
                        onMonthSelected(monthIdString);
                        Navigator.pop(context);
                        HapticHelper.selection();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary(context) : AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary(context)
                                : isCurrentMonth
                                    ? AppColors.warning(context)
                                    : AppColors.border(context),
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getShortMonthName(monthNumber),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSelected ? Colors.white : AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerStats(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = Colors.white.withValues(alpha: isDarkMode ? 0.15 : 0.25);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2E2E), Color(0xFF0D1B1A)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00C6A2), Color(0xFF00E3C3)],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 140, height: 12, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6))),
                Container(width: 40, height: 22, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(11))),
              ],
            ),
            const SizedBox(height: 16),
            Container(width: 130, height: 34, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Container(width: 110, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: isDarkMode ? 0.1 : 0.2), borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Container(height: 60, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(20)))),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 60, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(20)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Deleted _generateMonthOptions
}


class _SliverPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  final double minExtent;
  @override
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







