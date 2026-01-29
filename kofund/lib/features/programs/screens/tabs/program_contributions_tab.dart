import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../contributions/screens/program_deleted_contributions_screen.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/programs/widgets/add_contribution_modal.dart';
import 'package:kofund/features/history/screens/edit_contribution_screen.dart';
import 'package:kofund/features/programs/utils/contribution_receipt_pdf.dart';
import 'package:kofund/core/skeleton/history_list_skeleton.dart';
class ProgramContributionsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramContributionsTab({super.key, required this.program});

  @override
  State<ProgramContributionsTab> createState() => _ProgramContributionsTabState();
}
/// Simple SliverPersistentHeaderDelegate that pins a provided child.
class _PinnedStatsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _PinnedStatsHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // You can optionally animate scale/opacity based on shrinkOffset here.
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedStatsHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.maxExtent != maxExtent ||
        oldDelegate.minExtent != minExtent;
  }
}

class _ProgramContributionsTabState extends State<ProgramContributionsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMethod = 'all';
final Map<String, String> _localUserNameCache = {};

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

  // Check if current user is the contributor
  bool _isContributor(ContributionModel contribution, BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    return currentUser?.uid == contribution.userId;
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

  // Use the contributions stream here (we'll listen below in StreamBuilder)
  final contributionsStream = Provider.of<ContributionProvider>(context, listen: false)
      .streamProgramContributions(widget.program.programId);

  return Stack(
    children: [
      // Main scroll area with pinned stats
      StreamBuilder<List<ContributionModel>>(
        stream: contributionsStream,
        builder: (context, snapshot) {
          // Determine common states
          final connectionWaiting = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final allContributions = snapshot.data ?? <ContributionModel>[];
          final filtered = _filterContributions(allContributions);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ======= PINNED STATS HEADER =======
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedStatsHeaderDelegate(
                  minExtent: 120, // adjust as needed
                  maxExtent: 185, // adjust as needed
                  child: _buildContributionSummary(context),
                ),
              ),

              // ======= Search & Filter (scrolling) =======
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSearchFilterBar(context),
                ),
              ),

              // ======= Content: skeleton / error / empty / list =======
              if (connectionWaiting) ...[
                // Show skeleton as a sliver
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 8,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    // show your existing skeleton (HistoryListSkeleton) inside a sliver
                    height: 400,
                    child: HistoryListSkeleton(isDarkMode: Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              ] else if (hasError) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: AppColors.error(context), size: 48),
                        const SizedBox(height: 8),
                        Text('Error loading contributions', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                      ],
                    ),
                  ),
                )
              ] else if (filtered.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(allContributions.isEmpty, context),
                ),
              ] else ...[
                // Sliver list for contributions (keeps items performant)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final contribution = filtered[index];
                      final showMenu = isAdmin || _isContributor(contribution, context);
                      return _buildContributionCard(contribution, context, showMenu);
                    },
                    childCount: filtered.length,
                  ),
                ),
                // Add bottom padding so last item isn't hidden by FAB or bottom sheet
                SliverToBoxAdapter(
                  child: const SizedBox(height: 88),
                ),
              ],
            ],
          );
        },
      ),

      // Floating Action Button - pinned above scroll content
      Positioned(
        bottom: 16,
        right: 16,
        child: Visibility(
          visible: isAdmin,
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
Widget _buildSkeletonLoader(BuildContext context) {
  return ListView.builder(
    itemCount: 5,
    itemBuilder: (context, index) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Skeleton avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skeleton text
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // Skeleton amount
            Container(
              width: 60,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      );
    },
  );
}


Widget _buildSearchFilterBar(BuildContext context) {
  final isAdmin = _isAdmin(context);
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    child: Row(
      children: [
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
        
        const SizedBox(width: 8),
        
        Container(
          width: 120,
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
        
        // ✅ ADD THIS: Deleted Contributions Button (Only for Admin)
        if (isAdmin) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.border(context),
              ),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface(context),
            ),
            child: IconButton(
              onPressed: () => _navigateToProgramDeletedContributions(context),
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.error(context),
                size: 18,
              ),
              tooltip: 'View Deleted Contributions',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
void _navigateToProgramDeletedContributions(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProgramDeletedContributionsScreen(
        programId: widget.program.programId,
        programName: widget.program.title,
      ),
    ),
  );
}
  Widget _buildContributionCard(ContributionModel contribution, BuildContext context, bool showMenu) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showContributionDetails(contribution, context);
            },
            child: Container(

              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
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
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                     Row(
  children: [
    Text(
      contribution.contributorName, // Use contributorName directly
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
        fontSize: 15,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
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
                  
                  Row(
                    children: [
                      Text(
                        '₹${contribution.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      
                      if (showMenu)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: AppColors.textSecondary(context),
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onSelected: (value) {
                              _handleMenuAction(value, contribution, context);
                            },
                            itemBuilder: (BuildContext context) {
                              final isAdmin = _isAdmin(context);
                              final isContributor = _isContributor(contribution, context);
                              
                              List<PopupMenuEntry<String>> items = [];
                              
                              // View Details - Available to everyone
                              items.add(
                                const PopupMenuItem<String>(
                                  value: 'view_details',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text('View Details'),
                                    ],
                                  ),
                                ),
                              );
                              
                              // Edit - Only for admin
                              if (isAdmin) {
                                items.add(
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              // Get Receipt - Available to contributor and admin
                              if (isContributor || isAdmin) {
                                items.add(
                                  const PopupMenuItem<String>(
                                    value: 'receipt',
                                    child: Row(
                                      children: [
                                        Icon(Icons.receipt, size: 18),
                                        SizedBox(width: 8),
                                        Text('Get Receipt'),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              // Delete - Only for admin
                              if (isAdmin) {
                                items.add(
                                  const PopupMenuDivider(),
                                );
                                items.add(
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              return items;
                            },
                          ),
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

  void _handleMenuAction(String value, ContributionModel contribution, BuildContext context) {
    switch (value) {
      case 'view_details':
        _showContributionDetails(contribution, context);
        break;
      case 'edit':
        _editContribution(contribution, context);
        break;
      case 'receipt':
        _generateReceipt(contribution, context);
        break;
      case 'delete':
        _showDeleteConfirmation(contribution, context);
        break;
    }
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

void _showContributionDetails(ContributionModel contribution, BuildContext context) {
  final isAdmin = _isAdmin(context);
  final isContributor = _isContributor(contribution, context);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Color(0x66000000), // Semi-transparent black overlay
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping inside
          child: DraggableScrollableSheet(
            initialChildSize: contribution.isEdited ? 0.8 : 0.6,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.5, 0.75, 0.95],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF0F1F1D)
                      : Color(0xFFF8FDFC),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
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
                            color: AppColors.border(context).withOpacity(0.4),
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
                                  'Contribution Details',
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
                                    color: AppColors.primary(context).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    DateFormat('EEEE, MMMM dd • hh:mm a').format(contribution.createdAt.toDate()),
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
                          if (contribution.isEdited)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.withOpacity(0.15),
                                    Colors.orange.withOpacity(0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.2),
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
            contribution.amount.toStringAsFixed(2),
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

      // ───── CONTRIBUTOR ─────
      Text(
        contribution.contributorName, // Use contributorName directly
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
      ),

      // ───── MONTH CHIP ─────
      if (contribution.isMonthlyContribution &&
          contribution.monthDisplayName.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border(context),
              width: 0.6,
            ),
          ),
          child: Text(
            contribution.monthDisplayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ],
    ],
  ),
),

                            
// ───── BASIC INFORMATION (MINIMAL) ─────
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
      // ───── PAYMENT METHOD ─────
      _buildInfoRowMinimal(
        context,
        icon: Icons.payment_rounded,
        label: 'Payment Method',
        value: _formatPaymentMethod(contribution.paymentMethod),
      ),

      if (contribution.addedByUserName != null &&
          contribution.addedByUserName!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Divider(
          height: 1,
          thickness: 0.6,
          color: AppColors.border(context),
        ),
        const SizedBox(height: 12),

        // ───── ADDED BY ─────
        _buildInfoRowMinimal(
          context,
          icon: Icons.person_rounded,
          label: 'Added By',
          value: contribution.addedByUserName!,
        ),
      ],
    ],
  ),
),

                            
                         
                            
                            // EDIT HISTORY SECTION
                            if (contribution.isEdited)
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
            color: Colors.orange.withOpacity(0.10),
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


    // ───── MINIMAL TIMELINE ─────
    if (contribution.formattedEditHistory.isNotEmpty) ...[
      const SizedBox(height: 24),

      ...contribution.formattedEditHistory.map((edit) {
        final editedAt =
            (edit['editedAt'] as Timestamp?)?.toDate();
        final editedBy =
            edit['editedByUserName'] ??
            edit['editedByUserId'] ??
            'Unknown';

        final changes =
            (edit['changes'] as Map<String, dynamic>?) ?? {};
        final reason = edit['reason'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        ? DateFormat(
                                'MMM dd, yyyy hh:mm a')
                            .format(editedAt)
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
              ...changes.entries.map((fieldChange) {
                final fieldName =
                    _getFieldDisplayName(fieldChange.key);
                final change =
                    fieldChange.value as Map<String, dynamic>;
                final oldValue =
                    change['old']?.toString();
                final newValue =
                    change['new']?.toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            AppColors.textPrimary(context),
                      ),
                      children: [
                        const TextSpan(text: '•  '),
                        TextSpan(
                          text: '$fieldName: ',
                          style: const TextStyle(
                              fontWeight:
                                  FontWeight.w500),
                        ),
                        if (oldValue != null)
                          TextSpan(
                            text: oldValue,
                            style: TextStyle(
                              color: Colors
                                  .grey.shade600,
                            ),
                          ),
                        if (oldValue != null &&
                            newValue != null)
                          const TextSpan(text: '  →  '),
                        if (newValue != null)
                          const TextSpan(
                            text: '',
                          ),
                        if (newValue != null)
                          TextSpan(
                            text: newValue,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              // ───── REASON ─────
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Reason: $reason',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color:
                        AppColors.textTertiary(context),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    ],
  ],
),


                            
                            // Bottom Padding
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom Action Buttons - Premium Design
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
                            color: Colors.black.withOpacity(0.1),
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
            borderRadius: BorderRadius.circular(14),
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
    if (isContributor || isAdmin)
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ElevatedButton(
         onPressed: () {
  _generateReceipt(contribution, context); // Show receipt

},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shadowColor: AppColors.primary(context).withOpacity(0.3),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Get Receipt',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
          color: AppColors.primary(context).withOpacity(0.1),
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

// Helper method for premium info rows
Widget _buildInfoRowPremium(BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  required Color iconColor,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 20,
        color: iconColor,
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildEditHistoryItem(BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  required Color iconColor,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: iconColor),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// Helper method for info rows
Widget _buildInfoRow(BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 20,
        color: AppColors.textSecondary(context),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
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



// Helper method for field display names
String _getFieldDisplayName(String field) {
  final displayNames = {
    'amount': 'Amount',
    'paymentMethod': 'Payment Method',
    'userId': 'Member',
    'programId': 'Program',
    'monthId': 'Month',
    'isMonthlyContribution': 'Type',
    'communityId': 'Community',
    'createdAt': 'Date',
    'addedBy': 'Added By',
    'addedByUserName': 'Added By',
  };
  
  // Return the display name if found, otherwise convert camelCase to readable format
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


  Widget _buildDetailItem(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
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
      ),
    );
  }

  void _editContribution(ContributionModel contribution, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditContributionScreen(
          contributionId: contribution.contributionId,
          onSave: (updatedContribution) async {
            try {
              if (updatedContribution != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Contribution updated successfully'),
                    backgroundColor: AppColors.success(context),
                    duration: const Duration(seconds: 2),
                  ),
                );
                setState(() {});
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

Future<void> _generateReceipt(
  ContributionModel contribution,
  BuildContext context,
) async {
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    // Get user name
    final userName = await _getUserName(contribution.userId, context);

    if (!context.mounted) return;

    Navigator.of(context).pop();

    // Generate and show receipt
    await ContributionReceiptPdf.generateAndShowReceipt(
      context: context,
      contribution: contribution,
      contributorName: userName,
      programName: widget.program.title,
    );

  } catch (e, st) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    debugPrint('Receipt error: $e\n$st');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate receipt: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
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

// Update line 1899:
void _deleteContribution(ContributionModel contribution, BuildContext context) async {
  try {
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    
    // Show reason dialog first
    final reason = await _showDeleteReasonDialog(context);
    if (reason == null || reason.isEmpty) return; // User cancelled
    
    await contributionProvider.deleteContribution(
      contribution.contributionId,
      reason, // Add this parameter
    );
    
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

// Add this helper method
Future<String?> _showDeleteReasonDialog(BuildContext context) async {
  final reasonController = TextEditingController();
  
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete Contribution'),
      content: TextField(
        controller: reasonController,
        decoration: InputDecoration(
          hintText: 'Enter reason for deletion...',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = reasonController.text.trim();
            if (reason.isNotEmpty) {
              Navigator.pop(context, reason);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Delete'),
        ),
      ],
    ),
  );
}

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
   
      case 'upi':
        return 'UPI';
 
      default:
        return method;
    }
  }
}