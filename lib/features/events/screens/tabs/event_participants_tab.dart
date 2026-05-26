// ✅ FIXED: Stats logic and auto-close month selector
// ✅ ADDED: Skeleton shimmer effect for loading state
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/features/members/screens/member_profile_screen.dart';
import 'package:kofund/features/events/screens/add_participant_screen.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class SafeAsyncOperation {
  static Future<T?> execute<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required void Function() onDisposed,
  }) async {
    if (!context.mounted) {
      onDisposed();
      return null;
    }
    
    try {
      return await operation();
    } catch (e) {
      if (context.mounted) {
        rethrow;
      } else {
        onDisposed();
        return null;
      }
    }
  }
}

class EventParticipantsTab extends StatefulWidget {
  final EventModel event;
  final String? selectedMonth;

  const EventParticipantsTab({
    super.key,
    required this.event,
    this.selectedMonth,
  });

  @override
  State<EventParticipantsTab> createState() => _ParticipantsTabState();
}

class _ParticipantsTabState extends State<EventParticipantsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _updatingParticipants = {};
  String _searchQuery = '';
  String _filterStatus = 'all';
  
  int _streamKey = 0;
  
  List<ParticipantModel> _cachedParticipants = [];
  Map<String, dynamic>? _cachedStats;

  Stream<List<ParticipantModel>>? _participantsStream;
  Stream<Map<String, dynamic>>? _statsStream;
  String? _cachedStreamMonth;
  int _cachedStreamKey = -1;

  void _updateStreamsIfNeeded(BuildContext context) {
    if (_participantsStream == null || _statsStream == null || _cachedStreamMonth != widget.selectedMonth || _cachedStreamKey != _streamKey) {
      _participantsStream = _getParticipantsStream(context);
      _statsStream = _getStatsStream(context);
      _cachedStreamMonth = widget.selectedMonth;
      _cachedStreamKey = _streamKey;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onRefresh() async {
    try {
      setState(() {
        _streamKey++;
      });
    } catch (error) {
      debugPrint("Refresh error: $error");
    }
  }

  String _formatMonthDisplay(String monthId) {
    try {
      final parts = monthId.split('-');
      if (parts.length != 2) return monthId;
      
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      
      final date = DateTime(year, month, 1);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return monthId;
    }
  }

  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    
    if (currentUser == null) return false;
    if (currentUser.uid == widget.event.createdBy) return true;
    if (currentUser.role == 'admin') return true;
    if (currentUser.isAdmin == true) return true;
    
    return false;
  }

  Future<void> _navigateToAddParticipantScreen(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddParticipantScreen(
          event: widget.event,
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _streamKey++;
      });
    }
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
    final isAdmin = _isAdmin(context);
    _updateStreamsIfNeeded(context);

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
              
              SliverToBoxAdapter(
                child: _buildParticipantsStats(context),
              ),

              // STICKY HEADER for Search & Filter
              _buildPinnedSearchFilter(context),

              _buildParticipantsListSliver(context),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 88),
              ),
            ],
          ),
        ),

        if (isAdmin)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _navigateToAddParticipantScreen(context),
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  Widget _buildParticipantsListSliver(BuildContext context) {
    return StreamBuilder<List<ParticipantModel>>(
      key: ValueKey('participants-${widget.event.eventId}-${widget.selectedMonth ?? 'regular'}-$_streamKey'),
      initialData: _cachedParticipants,
      stream: _participantsStream,
      builder: (context, snapshot) {
        // Smart-cache: only overwrite if new data is non-empty or no cache yet
        if (snapshot.hasData) {
          final newData = snapshot.data!;
          if (newData.isNotEmpty || _cachedParticipants.isEmpty) {
            _cachedParticipants = List.from(newData);
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting && _cachedParticipants.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildShimmerSkeleton(),
          );
        }

        if (snapshot.hasError && _cachedParticipants.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: AppColors.error(context), size: 48),
                    const SizedBox(height: 8),
                    Text('Error loading participants', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }

        // Use cached or live data
        final participants = _cachedParticipants.isNotEmpty
            ? _cachedParticipants
            : (snapshot.data ?? []);
        
        final filteredParticipants = _filterParticipants(participants);

        if (filteredParticipants.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(participants.isEmpty, context),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _buildParticipantCard(filteredParticipants[index], context);
            },
            childCount: filteredParticipants.length,
          ),
        );
      },
    );
  }

  Widget _buildParticipantsStats(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      key: ValueKey(
        'stats-${widget.event.eventId}-${widget.selectedMonth ?? 'regular'}-$_streamKey',
      ),
      initialData: _cachedStats,
      stream: _statsStream,
      builder: (context, snapshot) {
        // Smart-cache: only overwrite if new data has meaningful values
        if (snapshot.hasData) {
          final newData = snapshot.data!;
          final newTotal = (newData['totalParticipants'] ?? 0) as int;
          final newCollected = (newData['totalCollected'] ?? 0.0) as double;
          // Only update cache if data is non-zero OR we have no cache yet
          if (newTotal > 0 || newCollected > 0 || _cachedStats == null) {
            _cachedStats = snapshot.data;
          }
        }
        
        // Show shimmer only on first load when no cache exists
        if ((snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) && _cachedStats == null) {
          return _buildShimmerStats();
        }

        // ALWAYS prefer cached data — never fall through to zero defaults
        final data = _cachedStats ?? snapshot.data ?? {
          'totalParticipants': 0,
          'paidParticipants': 0,
          'pendingParticipants': 0,
          'totalCollected': 0.0,
          'totalExpected': 0.0,
        };

        final int totalCount = data['totalParticipants'] ?? 0;
        final int paidCount = data['paidParticipants'] ?? 0;
        final int pendingCount = data['pendingParticipants'] ?? 0;
        final double totalCollected = data['totalCollected'] ?? 0.0;
        final double totalExpected = data['totalExpected'] ?? 0.0;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              // 🏆 Main Stats Card (Gap Layout Style)
              Container(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.event.isMonthlyPayment && widget.selectedMonth != null
                              ? "MONTHLY SUMMARY"
                              : "PARTICIPANTS OVERVIEW",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_alt_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                totalCount.toString(),
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
                    Text(
                      "₹${totalCollected.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                    if (totalExpected > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "of ₹${totalExpected.toStringAsFixed(0)} expected",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildStatChip(
                          context,
                          icon: Icons.check_circle_outline_rounded,
                          label: "PAID",
                          value: paidCount.toString(),
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          context,
                          icon: Icons.pending_outlined,
                          label: "PENDING",
                          value: pendingCount.toString(),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card(context) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context).withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSkeleton() {
    return Column(
      children: List.generate(5, (index) => _buildShimmerParticipantCard()),
    );
  }

  Widget _buildShimmerParticipantCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface(context))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 16, decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 14, decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
              Container(width: 60, height: 24, decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(12))),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.border(context)),
      ],
    );
  }

  Widget _buildShimmerStats() {
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
                Container(width: 120, height: 12, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6))),
                Container(width: 40, height: 22, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(11))),
              ],
            ),
            const SizedBox(height: 16),
            Container(width: 140, height: 34, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Container(width: 100, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: isDarkMode ? 0.1 : 0.2), borderRadius: BorderRadius.circular(6))),
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

  Stream<List<ParticipantModel>> _getParticipantsStream(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    
    if (widget.event.isMonthlyPayment && widget.selectedMonth != null) {
      return eventProvider.streamParticipantsWithMonthlyContributions(
        widget.event.eventId,
        widget.selectedMonth!,
        communityId: widget.event.communityId,
      );
    } else {
      return eventProvider.streamParticipantsWithContributions(
        widget.event.eventId,
        communityId: widget.event.communityId,
      );
    }
  }

  Widget _buildLegendItem(Color color, String text, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: AppColors.border(context),
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 9,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  // Removed redundant month selector dialog as it is now handled globally in EventDetailsScreen app bar.

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

  Stream<Map<String, dynamic>> _getStatsStream(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    
    if (widget.event.isMonthlyPayment && widget.selectedMonth != null) {
      return eventProvider.streamMonthlyFinancialSummary(
        widget.event.eventId,
        widget.selectedMonth!,
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
                  hintText: 'Search participants...',
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
                    _filterStatus = value;
                  });
                },
                itemBuilder: (context) => [
                  _buildFilterMenuItem('all', 'All Status', Icons.list_alt_rounded),
                  _buildFilterMenuItem('paid', 'Paid Only', Icons.check_circle_outline_rounded),
                  _buildFilterMenuItem('pending', 'Pending Only', Icons.pending_outlined),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(String value, String label, IconData icon) {
    final isSelected = _filterStatus == value;
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

  Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {
    final userName = participant.userName.isNotEmpty ? participant.userName : 'Unknown User';
    final contributionPaid = participant.contributionPaid ?? 0;
    final suggestedContribution = widget.event.suggestedContribution ?? 0;
    final hasPaidFull = suggestedContribution > 0 && contributionPaid >= suggestedContribution;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _navigateToMemberProfile(participant, context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary(context),
                          AppColors.primary(context).withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        userName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 14),
                  
                  // Name and subtle status indication
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (suggestedContribution > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasPaidFull 
                                      ? AppColors.success(context)
                                      : AppColors.warning(context),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasPaidFull 
                                  ? 'Fully Paid' 
                                  : 'Due: ₹${(suggestedContribution - contributionPaid).toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Big Contributed Amount
                  if (suggestedContribution > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '₹${contributionPaid.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: hasPaidFull ? AppColors.success(context) : AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    
                  const SizedBox(width: 8),

                  // Menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppColors.textTertiary(context),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    color: AppColors.card(context),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    ),
                    offset: const Offset(-8, 40),
                    onSelected: (value) async {
                      if (value == 'toggle_payment') {
                        await _togglePaymentStatus(participant, context);
                      } else if (value == 'remove') {
                        _showRemoveConfirmation(participant, context);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: 'toggle_payment',
                          child: FutureBuilder<bool>(
                            future: _checkParticipantPaidStatus(
                              participant.userId,
                              widget.event.eventId,
                              communityId: widget.event.communityId,
                            ),
                            builder: (context, snapshot) {
                              final isPaid = snapshot.data ?? false;
                              return FutureBuilder<String?>(
                                future: _getPaymentSubtitleWithRealData(participant),
                                builder: (context, subtitleSnapshot) {
                                  final subtitle = subtitleSnapshot.data;
                                  return Row(
                                    children: [
                                      Icon(
                                        isPaid ? Icons.payment : Icons.payment_outlined,
                                        color: isPaid ? AppColors.success(context) : AppColors.warning(context),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isPaid ? 'Mark as Pending' : 'Mark as Paid',
                                              style: TextStyle(
                                                color: AppColors.textPrimary(context),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (subtitle != null && subtitle.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary(context),
                                                    fontSize: 12,
                                                  ),
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
                        ),
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.error(context),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Remove from event',
                                style: TextStyle(
                                  color: AppColors.error(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.border(context)),
      ],
    );
  }

  Widget _buildEmptyState(bool noParticipants, BuildContext context) {
    final isAdmin = _isAdmin(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noParticipants ? Icons.people_outline : Icons.search_off,
              size: 80,
              color: AppColors.primary(context).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              noParticipants 
                ? 'No participants yet' 
                : 'No results found',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noParticipants 
                ? widget.event.isMonthlyPayment
                  ? 'No participants yet'
                  : 'Start by adding participants to your event to track their contributions.'
                : 'Try adjusting your search or filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
            ),
            if (noParticipants && isAdmin) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _navigateToAddParticipantScreen(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Participant'),
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

  List<ParticipantModel> _filterParticipants(List<ParticipantModel> participants) {
    List<ParticipantModel> filtered = participants;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((participant) =>
        participant.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        participant.userEmail.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_filterStatus == 'paid') {
      filtered = filtered.where((p) {
        final suggestedContribution = widget.event.suggestedContribution ?? 0;
        final contributionPaid = p.contributionPaid ?? 0;
        return suggestedContribution > 0 && contributionPaid >= suggestedContribution;
      }).toList();
    } else if (_filterStatus == 'pending') {
      filtered = filtered.where((p) {
        final suggestedContribution = widget.event.suggestedContribution ?? 0;
        final contributionPaid = p.contributionPaid ?? 0;
        return suggestedContribution == 0 || contributionPaid < suggestedContribution;
      }).toList();
    }

    return filtered;
  }

  void _navigateToMemberProfile(ParticipantModel participant, BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final userService = UserService();
      final UserModel? member = await userService.getUserById(participant.userId);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (member == null) {
        final fallbackMember = UserModel(
          uid: participant.userId,
          email: participant.userEmail,
          displayName: participant.userName,
          isAdmin: false,
          isApproved: true,
          communityId: widget.event.communityId,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          phoneNumber: '',
        );
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberProfileScreen(member: fallbackMember),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberProfileScreen(member: member),
          ),
        );
      }
      
      if (mounted) {
        setState(() {
          _streamKey++;
        });
      }
      
    } catch (error) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load member profile');
      }
    }
  }

  Future<void> _togglePaymentStatus(
    ParticipantModel participant,
    BuildContext context,
  ) async {
    try {
      final eventId = widget.event.eventId;
      final communityId = widget.event.communityId;
      final isMonthlyy = widget.event.isMonthlyPayment;
      final suggestedAmount = widget.event.suggestedContribution ?? 0.0;
      
      final authProvider = context.read<AppAuthProvider>();
      final contributionProvider = context.read<ContributionProvider>();

      if (suggestedAmount <= 0) {
        if (mounted) {
          SnackbarHelper.showInfo(context, 'This event has no suggested contribution amount');
        }
        return;
      }

      setState(() {
        _updatingParticipants[participant.userId] = true;
      });

      contributionProvider.clearCacheForUser(eventId, participant.userId);

      final contributions = await contributionProvider.getUserContributionsFo(
        eventId,
        participant.userId,
        communityId: communityId,
        forceRefresh: true,
      );

      if (isMonthlyy) {
        if (widget.selectedMonth == null) {
          SnackbarHelper.showWarning(context, 'Please select a month first');
          return;
        }

        // Filter contributions for the selected month
        final monthlyContributions = contributions.where(
          (c) => c.isMonthlyContribution && c.monthId == widget.selectedMonth,
        ).toList();

        // Calculate total paid for the month
        final totalPaid = monthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);

        if (totalPaid >= suggestedAmount) {
          // Already fully paid – ask for confirmation to mark as pending (remove contributions)
          final confirm = await DialogHelper.showConfirmationDialog(
            context,
            title: 'Mark as pending?',
            message: 'Are you sure you want to mark ${participant.userName} as pending? This will remove their contributions for the selected month.',
            confirmLabel: 'Confirm',
            cancelLabel: 'Cancel',
            isDestructive: false,
          );
          if (confirm == true) {
            await _removeContributions(
              contributionProvider: contributionProvider,
              context: context,
              eventId: eventId,
              userId: participant.userId,
              participantName: participant.userName,
              monthId: widget.selectedMonth,
              isMonthlyy: true,
              reason: 'Marked as pending by admin',
            );
          }
        } else {
          // Not fully paid – create a contribution for the remaining amount
          final remaining = suggestedAmount - totalPaid;
          await _createContribution(
            contributionProvider: contributionProvider,
            context: context,
            eventId: eventId,
            eventName: widget.event.title,
            communityId: communityId,
            userId: participant.userId,
            participantName: participant.userName,
            amount: remaining,
            monthId: widget.selectedMonth,
            isMonthlyy: true,
            authProvider: authProvider,
          );
        }
      } else {
        final totalPaid = contributions
            .where((c) => !c.isMonthlyContribution)
            .fold<double>(0.0, (sum, c) => sum + c.amount);

        if (totalPaid >= suggestedAmount) {
          // Show confirmation before marking as pending
          final confirm = await DialogHelper.showConfirmationDialog(
            context,
            title: 'Mark as pending?',
            message: 'Are you sure you want to mark ${participant.userName} as pending? This will remove their contributions.',
            confirmLabel: 'Confirm',
            cancelLabel: 'Cancel',
            isDestructive: true,
          );
          if (confirm == true) {
            await _removeContributions(
              contributionProvider: contributionProvider,
              context: context,
              eventId: eventId,
              userId: participant.userId,
              participantName: participant.userName,
              monthId: null,
              isMonthlyy: false,
              reason: 'Marked as pending by admin',
            );
          }
        } else {
          final remaining = suggestedAmount - totalPaid;
          await _createContribution(
            contributionProvider: contributionProvider,
            context: context,
            eventId: eventId,
            eventName: widget.event.title,
            communityId: communityId,
            userId: participant.userId,
            participantName: participant.userName,
            amount: remaining,
            monthId: null,
            isMonthlyy: false,
            authProvider: authProvider,
          );
        }
      }
    } catch (error) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update payment status');
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingParticipants.remove(participant.userId);
          _streamKey++;
        });
      }
    }
  }

  Future<void> _createContribution({
    required ContributionProvider contributionProvider,
    required BuildContext context,
    required String eventId,
    required String eventName,
    required String communityId,
    required String userId,
    required String participantName,
    required double amount,
    required String? monthId,
    required bool isMonthlyy,
    required AppAuthProvider authProvider,
  }) async {
    try {
      final contributionId = '${DateTime.now().millisecondsSinceEpoch}_$userId';
      
      final contribution = ContributionModel(
        contributionId: contributionId,
        eventId: eventId,
        eventName: eventName,
        userId: userId,
        contributorName: participantName,
        communityId: communityId,
        amount: amount,
        paymentMethod: 'cash',
        isMonthlyContribution: isMonthlyy,
        monthId: monthId,
        addedByUserId: authProvider.user?.uid,
        addedByUserName: authProvider.getUserDisplayName,
        addedAt: Timestamp.now(),
        createdAt: Timestamp.now(),
      );
      
      await contributionProvider.addContribution(contribution);
      contributionProvider.clearCacheForUser(eventId, userId);
      
      String message = monthId != null
          ? 'Marked $participantName as paid for ${_formatMonthDisplay(monthId)}'
          : 'Marked $participantName as paid';
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, message);
      }
    } catch (error) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to create contribution');
      }
      rethrow;
    }
  }

  Future<void> _removeContributions({
    required ContributionProvider contributionProvider,
    required BuildContext context,
    required String eventId,
    required String userId,
    required String participantName,
    required String? monthId,
    required bool isMonthlyy,
    required String reason,
  }) async {
    try {
      final contributions = await contributionProvider.getUserContributionsFo(
        eventId,
        userId,
        communityId: widget.event.communityId,
        forceRefresh: true,
      );
      
      List<String> contributionsToDelete = [];
      
      if (isMonthlyy && monthId != null) {
        contributionsToDelete = contributions
            .where((c) => c.isMonthlyContribution && c.monthId == monthId)
            .map((c) => c.contributionId)
            .toList();
      } else {
        contributionsToDelete = contributions
            .where((c) => !c.isMonthlyContribution)
            .map((c) => c.contributionId)
            .toList();
      }
      
      for (final contributionId in contributionsToDelete) {
        await contributionProvider.deleteContribution(contributionId, reason);
      }
      
      contributionProvider.clearCacheForUser(eventId, userId);
      
      String message = isMonthlyy && monthId != null
          ? 'Marked $participantName as pending for ${_formatMonthDisplay(monthId)}'
          : 'Marked $participantName as pending';
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, message);
      }
    } catch (error) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update payment status');
      }
      rethrow;
    }
  }

  void _showRemoveConfirmation(ParticipantModel participant, BuildContext context) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Remove Participant?',
      message: 'Are you sure you want to remove ${participant.userName} from this event?',
      confirmLabel: 'Remove',
      isDestructive: true,
      icon: Icons.person_remove_rounded,
    );

    if (result == true) {
      _removeParticipant(participant, context);
    }
  }

  void _removeParticipant(ParticipantModel participant, BuildContext context) async {
    try {
      final eventProvider = context.read<EventProvider>();
      await eventProvider.leave(
        participant.eventId, 
        participant.userId,
        communityId: widget.event.communityId,
      );
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Removed ${participant.userName} from event');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to remove participant');
      }
    }
  }

  Future<bool> _checkParticipantPaidStatus(
    String userId,
    String eventId, {
    String? communityId,
  }) async {
    try {
      final contributionProvider = context.read<ContributionProvider>();
      final suggestedAmount = widget.event.suggestedContribution ?? 0.0;
      
      if (suggestedAmount <= 0) return false;
      
      final contributions = await contributionProvider.getUserContributionsFo(
        eventId,
        userId,
        communityId: communityId,
        forceRefresh: true,
      );
      
      if (widget.event.isMonthlyPayment && widget.selectedMonth != null) {
        final monthlyContributions = contributions
            .where((c) => c.isMonthlyContribution && c.monthId == widget.selectedMonth)
            .toList();
        
        final totalPaid = monthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        return totalPaid >= suggestedAmount;
      } else {
        final nonMonthlyContributions = contributions
            .where((c) => !c.isMonthlyContribution)
            .toList();
        
        final totalPaid = nonMonthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        return totalPaid >= suggestedAmount;
      }
    } catch (error) {
      return false;
    }
  }

  Future<String?> _getPaymentSubtitleWithRealData(ParticipantModel participant) async {
    try {
      final contributionProvider = context.read<ContributionProvider>();
      final suggestedAmount = widget.event.suggestedContribution ?? 0.0;
      
      if (suggestedAmount <= 0) {
        return widget.event.isMonthlyPayment && widget.selectedMonth != null
            ? 'For ${_formatMonthDisplay(widget.selectedMonth!)}'
            : null;
      }
      
      final contributions = await contributionProvider.getUserContributionsFo(
        widget.event.eventId,
        participant.userId,
        communityId: widget.event.communityId,
        forceRefresh: true,
      );
      
      double totalPaid;
      
      if (widget.event.isMonthlyPayment && widget.selectedMonth != null) {
        final monthlyContributions = contributions
            .where((c) => c.isMonthlyContribution && c.monthId == widget.selectedMonth)
            .toList();
        
        totalPaid = monthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        
        if (totalPaid >= suggestedAmount) {
          return 'Fully paid for ${_formatMonthDisplay(widget.selectedMonth!)}';
        } else {
          return '₹${totalPaid.toStringAsFixed(0)}/₹${suggestedAmount.toStringAsFixed(0)} for ${_formatMonthDisplay(widget.selectedMonth!)}';
        }
      } else {
        final nonMonthlyContributions = contributions
            .where((c) => !c.isMonthlyContribution)
            .toList();
        
        totalPaid = nonMonthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        
        if (totalPaid >= suggestedAmount) {
          return 'Fully paid';
        } else {
          return '₹${totalPaid.toStringAsFixed(0)}/₹${suggestedAmount.toStringAsFixed(0)}';
        }
      }
    } catch (error) {
      return null;
    }
  }
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