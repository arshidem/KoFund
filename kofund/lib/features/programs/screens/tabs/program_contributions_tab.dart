import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:kofund/core/services/user_service.dart';
// Add this import for the modal
import '../../../../features/programs/widgets/add_contribution_modal.dart'; // Adjust the path as needed

class ProgramContributionsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramContributionsTab({super.key, required this.program});

  @override
  State<ProgramContributionsTab> createState() => _ProgramContributionsTabState();
}

class _ProgramContributionsTabState extends State<ProgramContributionsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMethod = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // Get user name for display
  Future<String> _getUserName(String userId, BuildContext context) async {
    try {
      final userService = UserService();
      final user = await userService.getUserById(userId);
      
      if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      
      // Fallback to email if name not available
      if (user != null && user.email != null && user.email!.isNotEmpty) {
        return user.email!;
      }
      
      return 'User $userId';
    } catch (e) {
      print('Error fetching user name: $e');
      return 'User $userId';
    }
  }

  // ✅ ADD: Show add contribution modal
void _showAddContributionModal(BuildContext context) {
  // Check if user is admin before allowing to add contribution
  if (!_isAdmin(context)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Only admins can add contributions'),
        backgroundColor: AppColors.error(context),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: AddContributionModal(
        preSelectedProgramId: widget.program.programId,
        preSelectedProgramName: widget.program.title,
        isMonthlyProgram: widget.program.isMonthlyPaymentProgram,
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin(context);
    
    return Stack(
      children: [
        Column(
          children: [
            // Contribution Summary Card (Progress Bar)
            _buildContributionSummary(context),
            
            // Search and Filter Bar
            _buildSearchFilterBar(context),
            
            // Contributions List
            Expanded(
              child: StreamBuilder<List<ContributionModel>>(
                stream: Provider.of<ContributionProvider>(context, listen: false)
                    .streamProgramContributions(widget.program.programId),
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
                            'Error loading contributions',
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

                  final contributions = snapshot.data ?? [];
                  final filteredContributions = _filterContributions(contributions);

                  if (filteredContributions.isEmpty) {
                    return _buildEmptyState(contributions.isEmpty, context);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    itemCount: filteredContributions.length,
                    itemBuilder: (context, index) {
                      final contribution = filteredContributions[index];
                      return _buildContributionCard(contribution, context, isAdmin);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        
        // ✅ ADD: Floating Action Button for adding contributions
        Positioned(
          bottom: 16,
          right: 16,
          child: Visibility(
            visible: isAdmin, // Only show if user is admin
            child: FloatingActionButton(
              onPressed: () => _showAddContributionModal(context),
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  // Rest of your existing methods remain the same...
  Widget _buildContributionSummary(BuildContext context) {
    return StreamBuilder<double>(
      stream: Provider.of<ContributionProvider>(context, listen: false)
          .streamProgramTotalContributions(widget.program.programId),
      builder: (context, totalSnapshot) {
        final totalCollected = totalSnapshot.data ?? 0.0;
        final totalExpected = widget.program.estimatedTotalAmount;
        final progressPercentage = widget.program.calculateProgress(totalCollected);

        return StreamBuilder<List<ContributionModel>>(
          stream: Provider.of<ContributionProvider>(context, listen: false)
              .streamProgramContributions(widget.program.programId),
          builder: (context, contributionsSnapshot) {
            final contributions = contributionsSnapshot.data ?? [];
            final totalCount = contributions.length;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8),
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
                            "Contributions Overview",
                            style: TextStyle(
                              color: AppColors.textCards(context).withOpacity(0.9),
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.payments,
                                color: AppColors.textCards(context),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$totalCount contributions',
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

                  /// ───────────────── Amount ─────────────────
                  Text(
                    "₹${totalCollected.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: AppColors.textCards(context),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (totalExpected > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "of ₹${totalExpected.toStringAsFixed(0)} expected",
                        style: TextStyle(
                          color: AppColors.textCards(context).withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  /// ───────────────── Progress Bar ─────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalExpected > 0 ? totalCollected / totalExpected : 0,
                      minHeight: 6,
                      backgroundColor: AppColors.textCards(context).withOpacity(0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textCards(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// ───────────────── Progress Info ─────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progressPercentage.toStringAsFixed(1)}% collected',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textCards(context).withOpacity(0.85),
                        ),
                      ),
                      if (totalExpected > totalCollected)
                        Text(
                          '₹${(totalExpected - totalCollected).toStringAsFixed(0)} remaining',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textCards(context).withOpacity(0.85),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Row(
        children: [
          // Search Field - Takes most of the space
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contributions...',
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
          
          // Spacing between search and filter
          const SizedBox(width: 8),
          
          // Filter Dropdown - Compact size
          Container(
            width: 120, // Fixed width for filter
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.border(context),
              ),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface(context),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterMethod,
                isExpanded: true,
                icon: Icon(
                  Icons.filter_list,
                  color: AppColors.textSecondary(context),
                  size: 18,
                ),
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 12,
                ),
                dropdownColor: AppColors.card(context),
                items: const [
                  DropdownMenuItem(
                    value: 'all', 
                    child: Text('All Methods'),
                  ),
                  DropdownMenuItem(
                    value: 'cash', 
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem(
                    value: 'online', 
                    child: Text('Online'),
                  ),
                  DropdownMenuItem(
                    value: 'upi', 
                    child: Text('UPI'),
                  ),
                  DropdownMenuItem(
                    value: 'bank_transfer', 
                    child: Text('Bank'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterMethod = value!;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(ContributionModel contribution, BuildContext context, bool isAdmin) {
    return Card(
      color: AppColors.card(context),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: AppColors.border(context),
          width: 0.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.success(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.check_circle,
            color: AppColors.success(context),
            size: 20,
          ),
        ),
        title: FutureBuilder<String>(
          future: _getUserName(contribution.userId, context),
          builder: (context, snapshot) {
            final userName = snapshot.data ?? 'User';
            return Text(
              userName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                fontSize: 15,
              ),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_formatPaymentMethod(contribution.paymentMethod)} • ${DateFormat('dd/MM/yyyy').format(contribution.createdAt.toDate())}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${contribution.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        onTap: isAdmin ? () {
          _showContributionActions(contribution, context);
        } : null,
      ),
    );
  }

  Widget _buildEmptyState(bool noContributions, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noContributions ? Icons.payments_outlined : Icons.search_off,
            size: 60,
            color: AppColors.textTertiary(context),
          ),
          const SizedBox(height: 8),
          Text(
            noContributions ? 'No Contributions Yet' : 'No Matching Contributions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            noContributions 
                ? 'Contributions will appear here when participants make payments'
                : 'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          // Show add contribution button in empty state if user is admin
          if (_isAdmin(context))
            ElevatedButton.icon(
              onPressed: () => _showAddContributionModal(context),
              icon: const Icon(Icons.add),
              label: const Text('Add First Contribution'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  List<ContributionModel> _filterContributions(List<ContributionModel> contributions) {
    List<ContributionModel> filtered = contributions;

    // Apply payment method filter
    if (_filterMethod != 'all') {
      filtered = filtered.where((contribution) => contribution.paymentMethod == _filterMethod).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((contribution) {
        // We'll filter by user name when we have it
        // For now, just return all
        return true;
      }).toList();
    }

    return filtered;
  }

  void _showContributionActions(ContributionModel contribution, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.25,
          maxChildSize: 0.6,
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
                      'Contribution Actions',
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
                        _showContributionDetails(contribution, context);
                      },
                    ),

                    // Delete Contribution
                    _buildActionTile(
                      context: context,
                      icon: Icons.delete_outline,
                      title: 'Delete Contribution',
                      color: AppColors.error(context),
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(contribution, context);
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
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

  void _showContributionDetails(ContributionModel contribution, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Contribution Details',
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
              FutureBuilder<String>(
                future: _getUserName(contribution.userId, context),
                builder: (context, snapshot) {
                  return _buildDetailRow('User', snapshot.data ?? 'User ${contribution.userId}');
                },
              ),
              _buildDetailRow('Amount', '₹ ${contribution.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Payment Method', _formatPaymentMethod(contribution.paymentMethod)),
              _buildDetailRow('Status', 'Completed'),
              _buildDetailRow('Date', DateFormat('dd MMM yyyy, hh:mm a').format(contribution.createdAt.toDate())),
              // Show month for monthly contributions
              if (contribution.isMonthlyContribution && contribution.monthId != null)
                _buildDetailRow('Month', _getMonthDisplayName(contribution.monthId!)),
              _buildDetailRow('Contribution ID', contribution.contributionId),
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

  // ✅ ADD: Helper method to display month name
  String _getMonthDisplayName(String monthId) {
    final parts = monthId.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);
    final monthName = DateFormat('MMMM').format(date);
    return "$monthName $year";
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

  void _showDeleteConfirmation(ContributionModel contribution, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Contribution',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this contribution of ₹ ${contribution.amount.toStringAsFixed(2)}?',
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
              _deleteContribution(contribution, context);
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

  void _deleteContribution(ContributionModel contribution, BuildContext context) async {
    try {
      final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
      await contributionProvider.deleteContribution(contribution.contributionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Contribution deleted successfully!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete contribution: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method;
    }
  }
}