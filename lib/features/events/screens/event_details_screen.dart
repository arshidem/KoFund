import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import
import 'package:kofund/ads/simple_banner_ad.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../../../features/participants/providers/participant_provider.dart';
import '../../../features/participants/models/participant_model.dart';
import '../../../features/auth/providers/app_auth_provider.dart';
import 'tabs/event_overview_tab.dart';
import 'tabs/event_participants_tab.dart';
import 'tabs/event_contributions_tab.dart';
import 'tabs/event_expenses_tab.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_styles.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/dialog_helper.dart';

// Import skeleton files
import '../../../../core/skeleton/event_overview_skeleton.dart';
import '../../../../core/skeleton/event_participants_skeleton.dart';
import '../../../../core/skeleton/event_contributions_skeleton.dart';
import '../../../../core/skeleton/event_expenses_skeleton.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabTtitles = [
    'Overview',
    'Participants',
    'Contributions',
    'Expenses'
  ];

  bool _iLoading = true;
  EventModel? _cache;
  final RefreshController _refreshController = RefreshController();

  // ✅ ADD: Month selection state
  String? _selectedMonth;
  int _currentDisplayYear = DateTime.now().year;
  Map<String, int> _monthPaymentCounts = {};
  bool _isLoadingMonths = false;
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTtitles.length, vsync: this);
    
    // Initialize selected month
    _selectedMonth = _formatMonthId(DateTime.now());
    
    _loaData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose(); // Dispose refresh controller
    super.dispose();
  }

  Future<void> _loaData() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    try {
      eventProvider.getEventById(widget.eventId).listen((event) {
        if (event != null && mounted) {
          setState(() {
            _cache = event;
            _iLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _iLoading = false;
        });
      }
    }
  }

// Replace your _refreshAllData method with this:
Future<void> _refreshAllData() async {
  debugPrint('🔄 DEBUG: Refreshing all event details data...');
  
  try {
    // Show loading state
    if (mounted) {
      setState(() {
        _iLoading = true;
      });
    }
    
    // Get providers
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    final communityId = _cache?.communityId;
    // Clear the cached event to force re-fetch
    setState(() {
      _cache = null;
    });
    
    // Method 1: Use refreshData if you added it to EventProvider
    try {
      await eventProvider.refreshData(widget.eventId);
    } catch (e) {
      debugPrint('⚠️ Could not call refreshData: $e');
    }
    
    // Method 2: Force re-fetch the event from Firestore
    // This is the most reliable way
    await eventProvider.loadEvents(communityId ?? '');
    
    // Wait a bit for Firestore to update
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Get freshhh event data
    final freshhh = await eventProvider.getEventById(widget.eventId).first;
    
    if (mounted) {
      setState(() {
        _cache = freshhh;
        _iLoading = false;
      });
    }
    
    // Complete the refresh
    _refreshController.refreshCompleted();
    debugPrint('✅ DEBUG: All event details refreshed successfully');
    
  } catch (e) {
    debugPrint('❌ DEBUG: Error refreshing event details: $e');
    
    if (mounted) {
      setState(() {
        _iLoading = false;
      });
    }
    
    _refreshController.refreshFailed();
    
    // Show error to user
    SnackbarHelper.showError(context, 'Failed to refresh: ${e.toString()}');
  }
}

  void _onRefresh() {
    if (_cache?.isMonthlyPayment ?? false) {
      _loadMonthPaymentCounts();
    }
    _refreshAllData();
  }

  // ✅ ADD: Month Selection Helpers
  String _formatMonthId(DateTime date) => DateFormat('yyyy-MM').format(date);

  String _formatMonthDisplay(String monthId) {
    try {
      final date = DateTime.parse('$monthId-01');
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return monthId;
    }
  }

  String _getShortMonthName(int month) {
    return DateFormat('MMM').format(DateTime(2024, month));
  }

  Future<void> _loadMonthPaymentCounts() async {
    if (_cache == null || !mounted) return;
    
    setState(() => _isLoadingMonths = true);
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final counts = await eventProvider.getMonthlyPaymentCounts(widget.eventId, communityId: _cache?.communityId);
      if (mounted) {
        setState(() {
          _monthPaymentCounts = counts;
          _isLoadingMonths = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMonths = false);
    }
  }

  void _showMonthSelectorDialog() {
    _loadMonthPaymentCounts();
    
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
                        onPressed: () => setDialogState(() => _currentDisplayYear--),
                      ),
                      Text(
                        '$_currentDisplayYear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: AppColors.primary(context), size: 20),
                        onPressed: () => setDialogState(() => _currentDisplayYear++),
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
                    final monthId = '$_currentDisplayYear-${monthNumber.toString().padLeft(2, '0')}';
                    final isSelected = monthId == _selectedMonth;
                    final paymentCount = _monthPaymentCounts[monthId] ?? 0;
                    final hasPayments = paymentCount > 0;
                    final isCurrentMonth = monthId == _formatMonthId(DateTime.now());
                    final isFutureMonth = DateTime.parse('$monthId-01').isAfter(DateTime.now());

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMonth = monthId;
                          _streamKey++;
                        });
                        Navigator.pop(context);
                        HapticHelper.selection();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary(context)
                              : isFutureMonth
                                  ? AppColors.surface(context)
                                  : hasPayments
                                      ? AppColors.success(context).withValues(alpha: 0.1)
                                      : AppColors.card(context),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getShortMonthName(monthNumber),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : isFutureMonth
                                        ? AppColors.textTertiary(context)
                                        : AppColors.textPrimary(context),
                              ),
                            ),
                            if (hasPayments)
                              Text(
                                '$paymentCount',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white70 : AppColors.success(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem(AppColors.primary(context), 'Selected', context),
                    _buildLegendItem(AppColors.success(context).withValues(alpha: 0.2), 'Collected', context),
                    _buildLegendItem(AppColors.warning(context), 'Current', context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context))),
      ],
    );
  }

  // ... rest of your existing methods (join, leave, buildTabSkeleton)

  Widget _buildTabSkeleton(int tabIndex) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final isMonthlyy = _cache?.isMonthlyPayment ?? false;
    
    switch (tabIndex) {
      case 0:
        return EventOverviewSkeleton(isDarkMode: isDarkMode);
      case 1:
        return EventParticipantsSkeleton(
          isDarkMode: isDarkMode,
          isMonthlyy: isMonthlyy,
        );
      case 2:
        return EventContributionsSkeleton(isDarkMode: isDarkMode);
      case 3:
        return EventExpensesSkeleton(isDarkMode: isDarkMode);
      default:
        return EventOverviewSkeleton(isDarkMode: isDarkMode);
    }
  }

@override
Widget build(BuildContext context) {
  final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
  final currentUserId = _authProvider.user?.uid;
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return GradientSheetScaffold(
    titleWidget: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _cache?.title ?? 'Event Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          if (_cache?.isMonthlyPayment ?? false) ...[
            const SizedBox(width: 12),
            Container(
              height: 20,
              width: 1,
              color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.15),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                HapticHelper.light();
                _showMonthSelectorDialog();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedMonth != null ? _formatMonthDisplay(_selectedMonth!) : 'Select Month',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary(context),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.primary(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    title: 'Event Details', // Fallback for voice over/accessibility
    headerHeight: 60,
    actions: currentUserId == null || _iLoading
        ? null
        : [
            StreamBuilder<List<ParticipantModel>>(
              stream: Provider.of<ParticipantProvider>(context, listen: false)
                  .streamEventParticipants(widget.eventId, communityId: _cache?.communityId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final participants = snapshot.data!;
                final hasUserJoined = participants.any(
                  (p) => p.userId == currentUserId && p.status == 'joined',
                );

                if (hasUserJoined) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      onPressed: () => _leave(context),
                      icon: Icon(
                        Icons.exit_to_app_rounded,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      tooltip: 'Leave Event',
                    ),
                  );
                }

                // CHECK IF FULL
                final totalParticipants = participants.length;
                final maxParticipants = _cache?.maxParticipants ?? 0;
                final isFixed = _cache?.participantType == 'fixed';
                final isFull = isFixed && totalParticipants >= maxParticipants;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    onPressed: isFull ? null : () => _join(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFull 
                          ? (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1)
                          : (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      elevation: isFull ? 0 : 2,
                      shadowColor: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      isFull ? 'Full' : 'Join',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isFull 
                            ? (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.5) 
                            : (isDarkMode ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
    belowHeader: Container(
      color: Colors.transparent,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        labelColor: AppColors.primary(context),
        unselectedLabelColor: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.55),
        indicatorColor: AppColors.primary(context),
        indicatorWeight: 3,
        indicatorPadding: EdgeInsets.zero,
        padding: AppStyles.screenPaddingHorizontal / 2,
        labelPadding: AppStyles.screenPaddingHorizontal / 2,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        tabs: _tabTtitles
            .map(
              (title) => Tab(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 70,
                  ),
                  child: Center(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ),
    body: Column(
      children: [
        // Main content area
        Expanded(
          child: _iLoading
              ? _buildTabSkeleton(_tabController.index)
              : _cache != null
                  ? TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        EventOverviewTab(
                          event: _cache!,
                        ),
                        EventParticipantsTab(
                          event: _cache!,
                          selectedMonth: _selectedMonth,
                        ),
                        EventContributionsTab(
                          event: _cache!,
                          selectedMonth: _selectedMonth,
                        ),
                        EventExpensesTab(
                          event: _cache!,
                          selectedMonth: _selectedMonth,
                        ),
                      ],
                    )
                  : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error(context),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Event not found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'The event you are looking for does not exist',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _onRefresh,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary(context),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                  ),
                                ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
        ),
        
        // Banner ad (shows in all states: loading, content, error)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 2),
          color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
          child: const SimpleBannerAd(),
        ),
      ],
    ),
  );
}

  // Join event method (keep existing)
  Future<void> _join(BuildContext context) async {
    try {
      final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final participantProvider =
          Provider.of<ParticipantProvider>(context, listen: false);
      final eventProvider =
          Provider.of<EventProvider>(context, listen: false);

      final currentUser = _authProvider.user;
      if (currentUser == null) {
        SnackbarHelper.showError(context, 'Please sign in to join the event');
        return;
      }

      final event = await eventProvider.getEventById(widget.eventId).first;
      if (event == null) return;

      final participants = await participantProvider
          .streamEventParticipants(widget.eventId, communityId: _cache?.communityId)
          .first;
      final participantCount = participants.length;

      final isFull = event.participantType == 'fixed' &&
          participantCount >= event.maxParticipants;

      if (isFull) {
        SnackbarHelper.showError(context, 'Event is full!');
        return;
      }

      final hasJoined = participants.any(
        (p) => p.userId == currentUser.uid && p.status == 'joined',
      );

      if (hasJoined) {
        SnackbarHelper.showInfo(context, 'You have already joined this event');
        return;
      }

      final participant = ParticipantModel(
        participantId: '',
        eventId: widget.eventId,
        eventName: event.title,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'User',
        userEmail: currentUser.email,
        communityId: event.communityId,
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: event.suggestedContribution != null ? 0 : null,
        hasPaidContribution: event.suggestedContribution == null,
      );

      await participantProvider.joinEvent(participant);
      if (!mounted) return;

      SnackbarHelper.showSuccess(context, 'Successfully joined the event!');
      
      // Refresh data after joining
      _refreshAllData();
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to join event: $e');
    }
  }

  // Leave event method (keep existing)
  Future<void> _leave(BuildContext context) async {
    final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final participantProvider =
        Provider.of<ParticipantProvider>(context, listen: false);

    final currentUser = _authProvider.user;
    if (currentUser == null) return;

    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Leave Event?',
      message: 'Are you sure you want to leave this event? You will no longer receive updates or participate in activities.',
      confirmLabel: 'Yes, Leave',
      cancelLabel: 'Keep it',
      isDestructive: true,
    );

    if (result == true) {
      HapticHelper.success();
      try {
        await participantProvider.leaveEvent(widget.eventId, currentUser.uid, communityId: _cache?.communityId);
        if (!mounted) return;

        // Success snackbar
        // Success snackbar
        SnackbarHelper.showSuccess(context, 'Left the event successfully!');
        
        // Refresh data after leaving
        _refreshAllData();
      } catch (e) {
        SnackbarHelper.showError(context, 'Failed to leave event: $e');
      }
    }
  }
}







