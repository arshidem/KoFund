import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../contributions/screens/event_deleted_contributions_screen.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/events/widgets/add_contribution_modal.dart';
import 'package:kofund/features/contributions/screens/edit_contribution_screen.dart';
import 'package:kofund/features/events/utils/contribution_receipt_image.dart';
import 'package:kofund/core/skeleton/history_list_skeleton.dart';
import '../../../../core/skeleton/receipt_skeleton.dart';
import '../../../participants/providers/participant_provider.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/features/contributions/screens/event_deleted_contributions_screen.dart';
class EventContributionsTab extends StatefulWidget {
  final EventModel event;

  const EventContributionsTab({super.key, required this.event});

  @override
  State<EventContributionsTab> createState() => _ContributionsTabState();
}
/// Simple SliverPersistentHeaderDelegate that pins a provided child.
class _PinnedStatsHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  final double minExtent;
  @override
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

class _ContributionsTabState extends State<EventContributionsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMethod = 'all';
  final Map<String, String> _localUserNnameCache = {};
  Map<String, dynamic>? _cachedStats;

  void _onRefresh() async {
    try {
      // Data is strenamed, so small delay is enough to simulate refresh feel
      // or we can force refresh if provider supports it
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Refresh error: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Check if current user is admin
  bool _isAdmin(BuildContext context) {
    final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = _authProvider.user;
    
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

  // Check if current user is the contributor
  bool _isContributor(ContributionModel contribution, BuildContext context) {
    final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = _authProvider.user;
    return currentUser?.uid == contribution.userId;
  }

  // Get user name for display
  Future<String> _getUserName(String userId, BuildContext context) async {
    try {
      final _userService = UserService();
      final user = await _userService.getUserById(userId);
      
      if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      
      // Fallback to email if name not available
      if (user != null && user.email.isNotEmpty) {
        return user.email;
      }
      
      return 'User $userId';
    } catch (e) {
      debugPrint('Error fetching user name: $e');
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
          preSelectedeventId: widget.event.eventId,
          preSelectedeventName: widget.event.title,
          isMonthlyEvent: widget.event.isMonthlyPayment,
        ),
      ),
    );
  }

  // ✅ New Pinned Header Delegate
  Widget _buildPinnedSearchFilter(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedStatsHeaderDelegate(
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
    final isAdmin = _isAdmin(context);

    // Use the contributions stream here (we'll listen below in StreamBuilder)
    final contributionsStream = Provider.of<ContributionProvider>(context, listen: false)
        .streamContributions(widget.event.eventId);

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

            return Container(
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

                  // ======= SCROLLABLE STATS CARD =======
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: _buildContributionSummary(context),
                    ),
                  ),

                  // ======= Search & Filter (STICKY) =======
                  _buildPinnedSearchFilter(context),

                  // ======= Content: skeleton / error / empty / list =======
                  if (connectionWaiting) ...[
                    SliverToBoxAdapter(
                      child: SizedBox(
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
                    // Sliver list for contributions
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
                    // Add bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 88),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

      // Floating Action Button - pinned above scroll content
      Positioned(
        bottom: 16,
        right: 16,
        child: StreamBuilder<List<ContributionModel>>(
          stream: contributionsStream,
          builder: (context, snapshot) {
            final contributions = snapshot.data ?? [];
            final filtered = _filterContributions(contributions);
            return Visibility(
              visible: isAdmin && filtered.isNotEmpty,
              child: FloatingActionButton(
                onPressed: () => _showAddContributionModal(context),
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


Widget _buildContributionSummary(BuildContext context) {
  return StreamBuilder<Map<String, dynamic>>(
    key: ValueKey(
      'contribution-summary-${widget.event.eventId}',
    ),
    stream: _getContributionStatsStream(context),
    builder: (context, snapshot) {
      // Update cache on new data
      if (snapshot.hasData) {
        _cachedStats = snapshot.data;
      }
      
      // Show shimmer only on first load with no cache
      if (snapshot.connectionState == ConnectionState.waiting && _cachedStats == null) {
        return _buildShimmerContributionStats(context);
      }

      final data = _cachedStats ?? {
        'totalCollected': 0.0,
        'totalContributions': 0,
      };

      final double totalCollected = data['totalCollected'] ?? 0.0;
      final int totalContributions = data['totalContributions'] ?? 0;

      // ✅ FIX: Get participant count from provider
      final participantProvider = Provider.of<ParticipantProvider>(context, listen: false);
      
      return StreamBuilder<int>(
        stream: participantProvider.streamEventParticipantCount(widget.event.eventId),
        builder: (context, participantSnapshot) {
          final participantCount = participantSnapshot.data ?? widget.event.currentParticipants;
          
          // ✅ Calculate target amount with proper fallback
          final double targetAmount;
          
          if (widget.event.totalAmount != null && widget.event.totalAmount! > 0) {
            targetAmount = widget.event.totalAmount!;
          } else if (widget.event.suggestedContribution != null && widget.event.suggestedContribution! > 0) {
            final count = participantCount > 0 ? participantCount : 
                         (widget.event.isFixedParticipants ? widget.event.maxParticipants : 1);
            targetAmount = widget.event.suggestedContribution! * count;
          } else {
            targetAmount = 0.0;
          }

          final double progress = targetAmount > 0
              ? (totalCollected / targetAmount).clamp(0, 1)
              : 0;
          
          final double progressPercentage = progress * 100;

          // For monthly events, we might want to show month-specific info
          final String targetLabel = widget.event.isMonthlyPayment
              ? "this month's goal"
              : "target";

          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
                          "CONTRIBUTIONS OVERVIEW",
                          style: TextStyle(
                            color: AppColors.textPrimary(context).withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.event.isMonthlyPayment)
                          Text(
                            "Monthly Progress",
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          Text(
                            "Total Collection",
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            color: AppColors.primary(context),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            totalContributions.toString(),
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Amount display with automatic scaling
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "₹${totalCollected.toStringAsFixed(0)}",
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                ),
                
                // Target information (only for non-monthly events)
                if (targetAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "of ₹${targetAmount.toStringAsFixed(0)} $targetLabel",
                      style: TextStyle(
                        color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else if (!widget.event.isMonthlyPayment && widget.event.suggestedContribution != null && participantCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "₹${widget.event.suggestedContribution!.toStringAsFixed(0)} × $participantCount participants",
                      style: TextStyle(
                        color: AppColors.textSecondary(context).withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                const SizedBox(height: 12),

                // Progress bar (Enabled for all events with a target)
                if (targetAmount > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.primary(context).withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Progress stats row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                           '${progressPercentage.toStringAsFixed(1)}% complete',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary(context),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${(targetAmount - totalCollected).toStringAsFixed(0)} left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
        },
      );
    },
  );
}

// Helper method to create stats stream
Stream<Map<String, dynamic>> _getContributionStatsStream(BuildContext context) {
  final eventProvider = Provider.of<EventProvider>(context, listen: false);
  
  if (widget.event.isMonthlyPayment) {
    // For monthly events, we use a fixed month (defaulting to current)
    // or we could use the selected month if we had one in this tab too.
    // For now, looking at the logic, it seems it handles global/current month.
    final currentMonthId = DateFormat('yyyy-MM').format(DateTime.now());
    return eventProvider.streamMonthlyFinancialSummary(widget.event.eventId, currentMonthId);
  } else {
    return eventProvider.streamFinancialSummary(widget.event.eventId);
  }
}

// Shimmer loading for contributions
Widget _buildShimmerContributionStats(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final shimmerColor = isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
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
          Container(width: 110, height: 12, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 6, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 12),
          Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(5))),
        ],
      ),
    ),
  );
}
Widget _buildSkeletonLoader(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final highlightColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;

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
                color: highlightColor,
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
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: highlightColor,
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
                color: highlightColor,
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
                hintText: 'Search contributions...',
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
        const SizedBox(width: 8),
        
        // Filter Button
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
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
          child: Material(
            color: Colors.transparent,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.tune_rounded,
                color: filterIconColorVal,
                size: 20,
              ),
              offset: const Offset(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                setState(() {
                  _filterMethod = value;
                });
              },
              itemBuilder: (context) => [
                _buildFilterMenuItem('all', 'All Methods', Icons.payments_outlined),
                _buildFilterMenuItem('cash', 'Cash', Icons.money_rounded),
                _buildFilterMenuItem('upi', 'UPI', Icons.mobile_friendly_rounded),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Deleted Button
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.error(context).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              onPressed: () => _navigateToDeletedContributions(context),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error(context),
                size: 20,
              ),
              tooltip: 'Deleted Contributions',
            ),
          ),
        ),
      ],
    ),
  );
}

PopupMenuItem<String> _buildFilterMenuItem(String value, String label, IconData icon) {
  final isSelected = _filterMethod == value;
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
void _navigateToDeletedContributions(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DeletedContributionsScreen(
        eventId: widget.event.eventId,
        name: widget.event.title,
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
                      color: AppColors.success(context).withValues(alpha: 0.1),
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
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
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
    final isAdmin = _isAdmin(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noContributions ? Icons.payments_outlined : Icons.search_off,
              size: 80,
              color: AppColors.primary(context).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              noContributions ? 'No Contributions Yet' : 'No Matching Contributions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              noContributions 
                  ? 'Contributions will appear here when participants make payments.'
                  : 'Try adjusting your search or filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
            ),
            if (noContributions && isAdmin) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _showAddContributionModal(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Contribution'),
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
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((contribution) {
        return contribution.contributorName.toLowerCase().contains(query) ||
               contribution.paymentMethod.toLowerCase().contains(query) ||
               contribution.amount.toString().contains(query);
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
          onTap: () {}, // P closing when tapping inside
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
                                    color: AppColors.primary(context).withValues(alpha: 0.08),
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shadowColor: AppColors.primary(context).withValues(alpha: 0.3),
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



// Helper method for field display nnames
String _getFieldDisplayName(String field) {
  final displayNames = {
    'amount': 'Amount',
    'paymentMethod': 'Payment Method',
    'userId': 'Member',
    'eventId': 'event',
    'monthId': 'Month',
    'isMonthlyContribution': 'type',
    'communityId': 'Community',
    'createdAt': 'Date',
    'addedBy': 'Added By',
    'addedByUserName': 'Added By',
  };
  
  // Return the display name if found, otherwise convert cnamelCase to readable format
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
              debugPrint('Error handling updated contribution: $e');
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
  ContributionModel contributionModel,
  BuildContext context,
) async {
  if (!context.mounted) return;

  try {
    // Generate and show receipt - it handles its own loading skeleton now
    await ContributionReceiptImage.generateAndShowReceipt(
      context: context,
      contribution: contributionModel,
      contributorName: contributionModel.contributorName,
      name: widget.event.title,
    );
  } catch (e, st) {
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




  void _showDeleteConfirmation(ContributionModel contribution, BuildContext context) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Delete Contribution?',
      message: 'Are you sure you want to delete this contribution of ₹ ${contribution.amount.toStringAsFixed(2)}?',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (result == true) {
      _deleteContribution(contribution, context);
    }
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
      reason, // Add this parnameter
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
  
  final result = await DialogHelper.showConfirmationDialog(
    context,
    title: 'Delete Reason',
    confirmLabel: 'Confirm Delete',
    isDestructive: true,
    icon: Icons.delete_outline_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Please provide a reason for deleteing this contribution:',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: reasonController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter reason for deletion...',
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context).withValues(alpha: 0.6),
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: AppColors.surface(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
          ),
        ),
      ],
    ),
  );

  if (result == true) {
    return reasonController.text.trim();
  }
  return null;
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







