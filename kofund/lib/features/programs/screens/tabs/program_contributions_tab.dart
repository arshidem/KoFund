import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/programs/widgets/add_contribution_modal.dart'; // Adjust the path as needed
import 'package:kofund/features/history/screens/edit_contribution_screen.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // ALL users can view details when clicking the card
            _showContributionDetails(contribution, context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Leading icon/avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.payments,
                    color: AppColors.success(context),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _getUserName(contribution.userId, context),
                        builder: (context, snapshot) {
                          final userName = snapshot.data ?? 'User';
                          return Row(
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Show edit badge if contribution was edited
                              if (contribution.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'Edited',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatPaymentMethod(contribution.paymentMethod)} • ${DateFormat('dd/MM/yyyy').format(contribution.createdAt.toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Trailing amount and menu icon (for admin only)
                Row(
                  children: [
                    // Amount
                    Text(
                      '₹${contribution.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    
                    // Menu icon for admin only
                    if (isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          icon: Icon(
                            Icons.more_vert,
                            color: AppColors.textSecondary(context),
                            size: 20,
                          ),
                          onPressed: () {
                            // Only admin can open action menu
                            _showContributionActions(contribution, context);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
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
      
      // Horizontal divider
      Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border(context),
      ),
    ],
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
  // Get itemData for this contribution to check permissions
  final canEditContribution = _checkEditPermission(contribution, context);
  final canDelete = _checkDeletePermission(contribution, context);
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Empty onTap to prevent inner taps from closing
            child: DraggableScrollableSheet(
              initialChildSize: _calculateInitialSheetSize(
                canEdit: canEditContribution,
                canDelete: canDelete,
              ),
              minChildSize: 0.4,
              maxChildSize: 0.7,
              snap: true,
              snapSizes: const [0.4, 0.5, 0.7],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),

                      // Contribution Title and Info
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Contribution Title/Type
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    contribution.isMonthlyContribution
                                        ? 'Monthly Contribution - ${contribution.monthDisplayName}'
                                        : 'One-time Contribution',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary(context),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Contribution Type Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Contribution',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Contribution Amount
                            Text(
                              NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                                  .format(contribution.amount),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary(context),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Contribution Date
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(contribution.createdAt.toDate()),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: AppColors.border(context),
                        thickness: 1,
                      ),

                      // Action Buttons
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // View Details
                              _buildActionTile(
                                context: context,
                                icon: Icons.info_outline_rounded,
                                title: 'View Details',
                                description: 'See complete contribution details',
                                color: AppColors.primary(context),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showContributionDetails(contribution, context);
                                },
                              ),

                              // Edit Contribution
                              if (canEditContribution)
                                _buildActionTile(
                                  context: context,
                                  icon: Icons.edit_outlined,
                                  title: 'Edit Contribution',
                                  description: 'Modify contribution details',
                                  color: Colors.blue,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _editContribution(contribution, context);
                                  },
                                ),

                              // Get Receipt
                              _buildActionTile(
                                context: context,
                                icon: Icons.receipt_long_outlined,
                                title: 'Get Receipt',
                                description: 'Download contribution receipt',
                                color: Colors.green,
                                onTap: () {
                                  Navigator.pop(context);
                                  _generateReceipt(contribution, context);
                                },
                              ),

                              // Share Contribution
                              _buildActionTile(
                                context: context,
                                icon: Icons.share_outlined,
                                title: 'Share Details',
                                description: 'Share contribution information',
                                color: Colors.purple,
                                onTap: () {
                                  Navigator.pop(context);
                                  _shareContribution(contribution, context);
                                },
                              ),

                              // Delete Contribution
                              if (canDelete)
                                _buildActionTile(
                                  context: context,
                                  icon: Icons.delete_outline_rounded,
                                  title: 'Delete Contribution',
                                  description: 'Remove this contribution permanently',
                                  color: Colors.red,
                                  isDestructive: true,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showDeleteConfirmation(contribution, context);
                                  },
                                ),

                              const SizedBox(height: 16),

                              // Cancel Button
                              SizedBox(
                                height: 55,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary(context),
                                    side: BorderSide(
                                      color: AppColors.border(context),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// Helper method to calculate initial sheet size based on available actions
double _calculateInitialSheetSize({
  required bool canEdit,
  required bool canDelete,
}) {
  int actionCount = 3; // Always have View, Receipt, Share
  if (canEdit) actionCount++;
  if (canDelete) actionCount++;
  
  if (actionCount <= 3) return 0.5;
  if (actionCount <= 4) return 0.55;
  return 0.6;
}

// Updated Action Tile Widget with corrected parameter name
Widget _buildActionTile({
  required BuildContext context,
  required IconData icon,
  required String title,
  String? description, // Changed from subtitle to description
  required Color color,
  bool isDestructive = false,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),

              // Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? Colors.red
                            : AppColors.textPrimary(context),
                      ),
                    ),
                    if (description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Chevron Icon
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary(context),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Helper methods
bool _checkEditPermission(ContributionModel contribution, BuildContext context) {
  final auth = context.read<AppAuthProvider>();
  final currentUser = auth.user;
  
  // Admin can always edit
  if (currentUser?.isAdmin == true) return true;
  
  // Check if user is the contributor
  return contribution.userId == currentUser?.uid;
}

bool _checkDeletePermission(ContributionModel contribution, BuildContext context) {
  final auth = context.read<AppAuthProvider>();
  final currentUser = auth.user;
  
  // Only admin can delete
  return currentUser?.isAdmin == true;
}

void _showContributionDetails(ContributionModel contribution, BuildContext context) {
  // Check if current user is admin
  final isAdmin = _isAdmin(context);
  final canEdit = _checkEditPermission(contribution, context);
  final canDelete = _checkDeletePermission(contribution, context);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {},
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              snap: true,
              snapSizes: const [0.5, 0.7, 0.95],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),

                      // Header Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and Type Badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    contribution.isMonthlyContribution
                                        ? 'Monthly Contribution'
                                        : 'One-time Contribution',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Three-dot menu button (for admin only)
                                if (isAdmin && (canEdit || canDelete))
                                  IconButton(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: AppColors.textSecondary(context),
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context); // Close details modal
                                      _showContributionActions(contribution, context);
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            
                            // Contribution Type Badge
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Contribution',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Contribution Amount
                            Text(
                              NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                                  .format(contribution.amount),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary(context),
                                height: 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Contribution Date and Time
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppColors.textTertiary(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(contribution.createdAt.toDate()),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary(context),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.textTertiary(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('hh:mm a').format(contribution.createdAt.toDate()),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary(context),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Monthly Contribution Info
                            if (contribution.isMonthlyContribution && contribution.monthDisplayName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.date_range,
                                      size: 14,
                                      color: AppColors.textTertiary(context),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      contribution.monthDisplayName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: AppColors.border(context),
                        thickness: 1,
                      ),

                      // Details Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Basic Information Card
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.border(context),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Contribution Information',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    _buildDetailRow(
                                      context,
                                      label: 'Payment Method',
                                      value: _formatPaymentMethod(contribution.paymentMethod),
                                      icon: Icons.payment,
                                    ),
                                    
                                    _buildDetailRow(
                                      context,
                                      label: 'Contribution ID',
                                      value: contribution.contributionId,
                                      icon: Icons.tag,
                                    ),
                                    
                                    // Added By info
                                    if (contribution.addedByUserName != null && contribution.addedByUserName!.isNotEmpty)
                                      _buildDetailRow(
                                        context,
                                        label: 'Added By',
                                        value: contribution.addedByUserName!,
                                        icon: Icons.person_add,
                                      ),
                                    
                                    // Note
                                    if (contribution.note != null && contribution.note!.isNotEmpty)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.note,
                                                size: 16,
                                                color: AppColors.textSecondary(context),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Note:',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textSecondary(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 24),
                                            child: Text(
                                              contribution.note!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textSecondary(context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              // Edit History Section (if edited)
                              if (contribution.isEdited)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Edit History',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Last Edited Info
                                      if (contribution.lastEditedByUserName != null)
                                        _buildDetailRow(
                                          context,
                                          label: 'Last Edited By',
                                          value: contribution.lastEditedByUserName!,
                                          icon: Icons.person,
                                        ),
                                      
                                      if (contribution.lastEditedAt != null)
                                        _buildDetailRow(
                                          context,
                                          label: 'Last Edited On',
                                          value: DateFormat('MMM dd, yyyy hh:mm a')
                                              .format(contribution.lastEditedAt!.toDate()),
                                          icon: Icons.calendar_today,
                                        ),
                                      
                                      // Edit Reason
                                      if (contribution.editReason != null && contribution.editReason!.isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            Text(
                                              'Edit Reason:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary(context),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                contribution.editReason!,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.textSecondary(context),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      
                                      // Changes Summary
                                      if (contribution.changesDescription.isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 12),
                                            Text(
                                              'Changes Made:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary(context),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.orange.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                contribution.changesDescription,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.textSecondary(context),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      
                                      // Detailed Edit History
                                      if (contribution.formattedEditHistory.isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 16),
                                            Text(
                                              'Edit History Timeline',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary(context),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            ...contribution.formattedEditHistory.map((edit) => 
                                              _buildEditHistoryItem(context, edit)
                                            ).toList(),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              
                              // Action Buttons (Only for admin)
                              if (isAdmin)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.border(context),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Admin Actions',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Edit Button (only if admin can edit)
                                      if (canEdit)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context); // Close details modal
                                            _editContribution(contribution, context);
                                          },
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Edit Contribution'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary(context),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      
                                      // Spacing between buttons
                                      if (canEdit && canDelete) const SizedBox(height: 8),
                                      
                                      // Delete Button (only if admin can delete)
                                      if (canDelete)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context); // Close details modal
                                            _showDeleteConfirmation(contribution, context);
                                          },
                                          icon: const Icon(Icons.delete),
                                          label: const Text('Delete Contribution'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      
                                      // Receipt Button (available to everyone)
                                      const SizedBox(height: 12),
                                      Divider(
                                        color: AppColors.border(context),
                                        thickness: 1,
                                        height: 1,
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      Text(
                                        'General Actions',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Receipt Button (for everyone)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context); // Close details modal
                                          _generateReceipt(contribution, context);
                                        },
                                        icon: const Icon(Icons.receipt),
                                        label: const Text('Get Receipt'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                // Only show receipt button for non-admin users
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.border(context),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Actions',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Receipt Button (for non-admin users)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context); // Close details modal
                                          _generateReceipt(contribution, context);
                                        },
                                        icon: const Icon(Icons.receipt),
                                        label: const Text('Get Receipt'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

void _editContribution(ContributionModel contribution, BuildContext context) {
  // Navigate to edit contribution screen
  print('Edit contribution: ${contribution.contributionId}');
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditContributionScreen(
        contributionId: contribution.contributionId,
        onSave: (updatedContribution) async {
          try {
            if (updatedContribution != null) {
              // Contribution was updated
              print('Contribution updated successfully');
              
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Contribution updated successfully'),
                  backgroundColor: AppColors.success(context),
                  duration: const Duration(seconds: 2),
                ),
              );
              
              // Refresh the contributions list
              setState(() {});
            } else {
              // Edit was cancelled
              print('Edit cancelled');
            }
          } catch (e) {
            print('Error handling updated contribution: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: AppColors.error(context),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      ),
    ),
  );
}

void _generateReceipt(ContributionModel contribution, BuildContext context) {
  // Generate and show receipt
  // Check if you have a receipt generator that works with ContributionModel
  // If not, you can create a simpler version
  
  // Option 1: If you have a receipt generator
  // ContributionReceiptPdf.showPreviewFromContribution(context, contribution);
  
  // Option 2: Create a simple receipt
  _showSimpleReceipt(contribution, context);
}

void _showSimpleReceipt(ContributionModel contribution, BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card(context),
      title: Text(
        'Contribution Receipt',
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Receipt for Contribution',
              style: TextStyle(
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            _buildReceiptDetail('Amount:', '₹${contribution.amount.toStringAsFixed(2)}'),
            _buildReceiptDetail('Date:', DateFormat('MMM dd, yyyy').format(contribution.createdAt.toDate())),
            _buildReceiptDetail('Payment Method:', _formatPaymentMethod(contribution.paymentMethod)),
            _buildReceiptDetail('Contribution ID:', contribution.contributionId),
            if (contribution.isMonthlyContribution)
              _buildReceiptDetail('Month:', contribution.monthDisplayName),
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
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // Generate and download PDF
            _downloadReceipt(contribution, context);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary(context),
          ),
          child: const Text('Download PDF'),
        ),
      ],
    ),
  );
}

Widget _buildReceiptDetail(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(value),
      ],
    ),
  );
}

Future<void> _downloadReceipt(ContributionModel contribution, BuildContext context) async {
  // Implement PDF generation and download
  // You can use packages like pdf, printing, etc.
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Receipt download started'),
      backgroundColor: AppColors.success(context),
    ),
  );
}

void _shareContribution(ContributionModel contribution, BuildContext context) {
  // Share contribution details
  final shareText = '''
Contribution Receipt

Amount: ₹${contribution.amount}
Date: ${DateFormat('MMM dd, yyyy').format(contribution.createdAt.toDate())}
Time: ${DateFormat('hh:mm a').format(contribution.createdAt.toDate())}
Payment Method: ${_formatPaymentMethod(contribution.paymentMethod)}
${contribution.isMonthlyContribution ? 'Month: ${contribution.monthDisplayName}' : ''}
Contribution ID: ${contribution.contributionId}
${contribution.note != null ? 'Note: ${contribution.note}' : ''}

Thank you for your contribution!
''';
  
  // Show a dialog with the text
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Share Contribution'),
      content: SingleChildScrollView(
        child: Text(shareText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            // Copy to clipboard
            _copyToClipboard(shareText, context);
            Navigator.pop(context);
          },
          child: const Text('Copy'),
        ),
      ],
    ),
  );
}

// Helper method to copy text to clipboard
void _copyToClipboard(String text, BuildContext context) {
  try {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to copy: $e'),
        backgroundColor: AppColors.error(context),
      ),
    );
  }
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

Widget _buildDetailRow(BuildContext context, {
  required String label,
  required String value,
  required IconData icon,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildEditHistoryItem(BuildContext context, Map<String, dynamic> edit) {
  final editedAt = (edit['editedAt'] as Timestamp?)?.toDate();
  final editedBy = edit['editedByUserName'] ?? edit['editedByUserId'] ?? 'Unknown User';
  final changes = (edit['changes'] as Map<String, dynamic>?) ?? {};
  final reason = edit['reason'];
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with date and editor
        Row(
          children: [
            Icon(
              Icons.history,
              size: 12,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                editedAt != null 
                  ? DateFormat('MMM dd, yyyy hh:mm a').format(editedAt)
                  : 'Unknown time',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              'By: $editedBy',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        
        // Changes
        if (changes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Changes:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          ...changes.entries.map((entry) {
            final field = entry.key;
            final change = entry.value as Map<String, dynamic>;
            final oldValue = change['old']?.toString() ?? '';
            final newValue = change['new']?.toString() ?? '';
            final fieldName = _getFieldDisplayName(field);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  children: [
                    TextSpan(
                      text: '• $fieldName: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: '$oldValue ',
                      style: TextStyle(
                        color: Colors.red,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const TextSpan(text: '→ '),
                    TextSpan(
                      text: newValue,
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
        
        // Reason
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Reason:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

String _getFieldDisplayName(String field) {
  final displayNames = {
    'amount': 'Amount',
    'paymentMethod': 'Payment Method',
    'userId': 'Member',
    'programId': 'Program',
    'note': 'Note',
    'monthId': 'Month',
    'isMonthlyContribution': 'Type',
    'communityId': 'Community',
  };
  
  return displayNames[field] ?? field;
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