import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';
import '../constants/event_Types.dart';
import 'create_event_screen.dart';
import 'event_details_screen.dart';
import 'edit_event_screen.dart';
import 'event_reminder_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:kofund/core/skeleton/all_event_skeleton.dart';
import '../../participants/providers/participant_provider.dart';
enum StatusFilter {
  all,
  ongoing,
  completed,
  cancelled,
}

class Filters {
  StatusFilter statusFilter;
  String? eventType;
  bool? monthlyOnly;
  bool? availableOnly;

  Filters({
    this.statusFilter = StatusFilter.all,
    this.eventType,
    this.monthlyOnly,
    this.availableOnly,
  });

  Filters copyWith({
    StatusFilter? statusFilter,
    String? eventType,
    bool? monthlyOnly,
    bool? availableOnly,
    bool cleaTeventType = false,
  }) {
    return Filters(
      statusFilter: statusFilter ?? this.statusFilter,
      eventType: cleaTeventType ? null : (eventType ?? this.eventType),
      monthlyOnly: monthlyOnly ?? this.monthlyOnly,
      availableOnly: availableOnly ?? this.availableOnly,
    );
  }
}

class AllEventsScreen extends StatefulWidget {
  final bool isAdmin;

  const AllEventsScreen({
    super.key,
    required this.isAdmin,
  });

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  Filters _filters = Filters();
  bool _initialLoadAttempted = false;

  int _getActiveFilterCount() {
    int count = 0;
    if (_filters.statusFilter != StatusFilter.all) count++;
    if (_filters.eventType != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    // ✅ Data is triggered in didChangeDependencies to ensure communityId is available
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToRemindersScreen(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRemindersScreen(event: event),
      ),
    );
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Reactive Loading: If auth data arrives late or changed, trigger load
    final _authProvider = Provider.of<AppAuthProvider>(context);
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    final communityId = _authProvider.user?.communityId;
    
    if (communityId != null && 
        !_initialLoadAttempted && 
        !eventProvider.isLoading) {
      // debugPrint('🚀 DEBUG: Initial events load triggered in AllEventsScreen');
      _initialLoadAttempted = true;
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    // Ensure we don't call this if the widget is not mounted or in a precarious state
    if (!mounted) return;
    
    final _authProvider = context.read<AppAuthProvider>();
    final eventProvider = context.read<EventProvider>();
    
    final communityId = _authProvider.user?.communityId;
    if (communityId != null) {
      // debugPrint('📥 Loading events for community: $communityId (forceRefresh: true)');
      await eventProvider.loadEvents(communityId, forceRefresh: true);
      
      if (mounted) {
        await eventProvider.loadMyParticipations(
          _authProvider.user!.uid, 
          communityId,
        );
        
        // Use postFrname to avoid modifying state during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) eventProvider.syncEventsStatus();
        });
      }
    } else {
      debugPrint('⚠️ Cannot load events: communityId is null');
    }
  }

  Future<void> _onRefresh() async {
    HapticHelper.light();
    
    try {
      await _loadEvents();
      debugPrint('✅ DEBUG: events refresh completed successfully');
    } catch (e) {
      debugPrint('❌ DEBUG: events refresh failed: $e');
    }
  }

List<EventModel> _applyFilters(List<EventModel> events) {
  return events.where((event) {
    if (_filters.statusFilter != StatusFilter.all) {
      switch (_filters.statusFilter) {
        case StatusFilter.ongoing:
          if (!event.isOngoing) return false; // This now uses computedStatus
          break;
        case StatusFilter.completed:
          if (!event.isCompleted) return false; // This now uses computedStatus
          break;
        case StatusFilter.cancelled:
          if (!event.isCancelled) return false; // This now uses computedStatus
          break;
        default:
          break;
      }
    }

      if (_filters.eventType != null && _filters.eventType != 'all') {
        if (event.eventType != _filters.eventType) return false;
      }

      if (_filters.monthlyOnly == true) {
        if (!event.isMonthlyPayment) return false;
      }

      if (_filters.availableOnly == true) {
        if (!event.canJoin) return false;
      }

      return true;
    }).toList();
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusExtraLarge)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.65,
          child: FilterSheet(
            filters: _filters,
            onFiltersChanged: (newFilters) {
              setState(() {
                _filters = newFilters;
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final isAdmin = widget.isAdmin;
    List<EventModel> filteredEvents = eventProvider.events;
    
    if (_searchQuery.isNotEmpty) {
      filteredEvents = filteredEvents.where((event) {
        return event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               event.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               event.location.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // ✅ APPLY SELECTED FILTERS
    filteredEvents = _applyFilters(filteredEvents);
    
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context),
          ];
        },
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async => _onRefresh(),
            ),
            _buildActiveFilterChips(),
            _buildBodyContent(eventProvider, filteredEvents),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
      floatingActionButton: (isAdmin && eventProvider.events.isNotEmpty)
          ? FloatingActionButton(
              onPressed: () => _navigateToCreat(context),
              backgroundColor: const Color(0xFF00BFA5),
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double expandedHeightConfig = 160.0;
    final double collapsedHeightConfig = 72.0 + 12.0; 

    return SliverAppBar(
      expandedHeight: expandedHeightConfig,
      toolbarHeight: collapsedHeightConfig,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: AppColors.background(context),
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          final double expandedHeight = expandedHeightConfig + statusBarHeight;
          final double collapsedHeight = collapsedHeightConfig + statusBarHeight;
          
          final double rawProgress = (top - collapsedHeight) / (expandedHeight - collapsedHeight);
          final double progress = rawProgress.clamp(0.0, 1.0);
          
          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          
          final double titleTop = statusBarHeight + 16 + (4 * progress);
          final double titleFontSize = 24 + (4 * progress);
          
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: isDark 
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1A2E2E),
                            Color(0xFF0D1B1A),
                          ],
                        )
                      : null,
                ),
              ),
              
              
              Positioned(
                top: titleTop,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Events',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        color: isDark 
                            ? Colors.white 
                            : AppColors.textPrimary(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
              
              Positioned(
                top: statusBarHeight + 10,
                right: 24.0,
                child: Opacity(
                  opacity: (0.5 - progress).clamp(0.0, 0.5) * 2.0,
                  child: IgnorePointer(
                    ignoring: progress > 0.5,
                    child: _buildCollapsedActionIcons(context),
                  ),
                ),
              ),
              
              Positioned(
                bottom: 34.0, 
                left: 24.0,
                right: 24.0,
                child: Opacity(
                  opacity: (progress - 0.5).clamp(0.0, 0.5) * 2.0,
                  child: IgnorePointer(
                    ignoring: progress < 0.5,
                    child: _buildExpandedSearchRow(context),
                  ),
                ),
              ),
              
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Widget _buildExpandedSearchRow(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color searchBg = isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.card(context).withValues(alpha: 0.8);
    final Color searchBorder = isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context);
    final Color textColor = isDark ? Colors.white : AppColors.textPrimary(context);
    final Color iconColorVal = isDark ? Colors.white70 : Colors.black;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: searchBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
                letterSpacing: 0.3,
              ),
              cursorColor: textColor,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Search events...',
                filled: false,
                hintStyle: TextStyle(
                  color: iconColorVal,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: iconColorVal,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: iconColorVal,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildFilterButton(context, 52, 52),
      ],
    );
  }

  Widget _buildCollapsedActionIcons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          context, 
          icon: Icons.search, 
          onTap: () {
            _scrollController.animateTo(
              0.0, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeOut,
            );
          }
        ),
        const SizedBox(width: 8),
        _buildFilterButton(context, 44, 44, collapsed: true),
      ],
    );
  }

  Widget _buildIconButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.textSecondary(context),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, double width, double height, {bool collapsed = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int filterCount = _getActiveFilterCount();
    
    return Container(
      width: width,
      height: height,
      decoration: collapsed
          ? null
          : BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.card(context).withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context),
                width: 1,
              ),
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _openFilterSheet(context),
          child: Center(
            child: badges.Badge(
              showBadge: filterCount > 0,
              badgeContent: Text(
                filterCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              badgeStyle: badges.BadgeStyle(
                badgeColor: AppColors.error(context),
                padding: const EdgeInsets.all(4),
                elevation: 0,
              ),
              position: badges.BadgePosition.topEnd(top: -6, end: -6),
              child: Icon(
                Icons.tune,
                color: collapsed 
                    ? AppColors.textSecondary(context) 
                    : (isDark ? Colors.white : Colors.black),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(int resultCount) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary(context).withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: AppColors.primary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search results for "$_searchQuery"',
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
            ),
            child: Text(
              '$resultCount ${resultCount == 1 ? 'event' : 'events'}',
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildBodyContent(EventProvider eventProvider, List<EventModel> displayEvents) {
  final bgColor = AppColors.background(context);
  
  if (eventProvider.isLoading && displayEvents.isEmpty) {
    return AllEventsSkeleton.buildSliver(
      context, 
      Theme.of(context).brightness == Brightness.dark,
    );
  }

  if (eventProvider.error != null && displayEvents.isEmpty) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                eventProvider.error!,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEvents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
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
    );
  }

  if (displayEvents.isEmpty) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Container(
        color: bgColor,
        child: _buildEmptyState(),
      ),
    );
  }

  return SliverPadding(
    padding: const EdgeInsets.only(top: 0),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final event = displayEvents[index];
          return Container(
            color: bgColor,
            child: TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: _builCard(event, eventProvider, context.read<AppAuthProvider>()),
            ),
          );
        },
        childCount: displayEvents.length,
      ),
    ),
  );
}

  Widget _buildEmptyState() {
    final isAdmin = widget.isAdmin;

    return Padding(
      padding: const EdgeInsets.only(top: 80, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEmptyIcon(),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'No results found' : 'No Events Available',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchQuery.isNotEmpty 
                  ? 'Try adjusting your search or filters'
                  : isAdmin
                      ? 'Create the first event for your community.'
                      : 'No events available yet. Check back later.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          if (_searchQuery.isNotEmpty)
            _buildActionButton('Clear Search', () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            })
          else if (isAdmin)
            _buildActionButton(
              'Create event', 
              () => _navigateToCreat(context), 
              icon: Icons.add_rounded
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyIcon() {
    final color = AppColors.primary(context).withValues(alpha: 0.5);
    if (_searchQuery.isNotEmpty) {
      return Icon(Icons.search_off, size: 64, color: color);
    }
    return Icon(Icons.event_note_rounded, size: 64, color: color);
  }

  Widget _buildActionButton(String label, VoidCallback onPressed, {IconData? icon}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary(context),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
      ),
    );
  }


// Premium event Card Section

// Replace the _builCard method with this corrected version

Widget _builCard(
  EventModel event,
  EventProvider eventProvider,
  AppAuthProvider authProvider,
) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final hasJoined = eventProvider.hasUserJoined(event.eventId, authProvider.user!.uid);
  final olor = _geColor(event.eventType);

  return Consumer<ParticipantProvider>(
    builder: (context, participantProvider, _) {
      return Container(
        margin: EdgeInsets.fromLTRB(AppDimensions.screenPaddingHorizontal, 0, AppDimensions.screenPaddingHorizontal, 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: InkWell(
          onTap: () => _viewDetails(event),
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          child: StreamBuilder<Map<String, dynamic>>(
                  stream: eventProvider.streamProgress(event.eventId),
                  builder: (context, progressSnap) {
                    final progressData = progressSnap.data ?? {
                      'collected': 0.0,
                      'target': 100.0,
                      'percentage': 0.0,
                      'participantCount': event.currentParticipants,
                      'isMonthlyy': event.isMonthlyPayment,
                    };
                    
                    final collectedAamount = (progressData['collected'] as num).toDouble();
                    final targetAmount = (progressData['target'] as num).toDouble();
                    final progress = (progressData['percentage'] as num).toDouble();
                    final totalParticipants = progressData['participantCount'] as int;
                    final maxParticipants = event.maxParticipants;
                    
                    final now = DateTime.now();
                    final daysLeft = (event.isMonthlyPayment || event.eventDate == null)
                        ? null 
                        : event.eventDate!.difference(now).inDays;
                    
                    final canJoin = !hasJoined &&
                        (!event.isFixedParticipants ||
                            (event.maxParticipants > totalParticipants));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Icon + Ttitle + Status/Admin
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: olor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    EventTypes.getIconData(event.eventType),
                                    color: olor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary(context),
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        event.eventType.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: olor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.isAdmin)
                                  _buildAdminMenu(event, eventProvider)
                                else if (!event.isMonthlyPayment)
                                  _buildStatusBadge(event, progress, daysLeft ?? 0),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (event.description.isNotEmpty) ...[
                              Text(
                                event.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary(context),
                                  height: 1.5,
                                ),
                                maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                              ],
                              
                              // Progress Bar Section
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        event.isMonthlyPayment ? 'Current Month' : 'Total Progress',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary(context),
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: olor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          Container(
                                            height: 8,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: olor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          TweenAnimationBuilder<double>(
                                            duration: const Duration(milliseconds: 1200),
                                            curve: Curves.easeOutQuart,
                                            tween: Tween<double>(begin: 0, end: progress),
                                            builder: (context, animValue, child) {
                                              return Container(
                                                height: 8,
                                                width: constraints.maxWidth * animValue,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [olor, olor.withValues(alpha: 0.7)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                 ],
                              ),
                              const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildCompactStat(
                                      Icons.people_outline_rounded,
                                      '$totalParticipants${maxParticipants > 0 ? "/$maxParticipants" : ""}',
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: hasJoined 
                                    ? () => _viewDetails(event)
                                    : (canJoin ? () => _join(event, eventProvider, authProvider) : null),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: hasJoined || canJoin ? olor : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      boxShadow: [
                                        if (hasJoined || canJoin)
                                          BoxShadow(
                                            color: olor.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          hasJoined ? 'DETAILS' : (canJoin ? 'JOIN NOW' : 'Full'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: hasJoined || canJoin ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded, 
                                          size: 10, 
                                          color: hasJoined || canJoin ? Colors.white : Colors.white.withValues(alpha: 0.6)
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                  },
              ),
          ),  // InkWell child
        );  // Container return
      },  // Consumer builder
    );  // Consumer
  }  // _builCard
// Your existing _buildStatItem method (unchanged)
// Replaced by compact stat helpers




  Widget _buildAdminMenu(EventModel event, EventProvider eventProvider) {
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
        if (value == 'edit') {
          _edi(event);
        } else if (value == 'delete') {
          _showDeleteConfirmation(event, eventProvider);
        } else if (value == 'reminders') {
          _navigateToRemindersScreen(event);
        }
      },
      itemBuilder: (BuildContext context) => [
        _buildPopupMenuItem(
          value: 'edit',
          icon: Icons.edit_rounded,
          label: 'Edit event',
          color: AppColors.primary(context),
        ),
        _buildPopupMenuItem(
          value: 'reminders',
          icon: Icons.notifications_active_rounded,
          label: 'Reminders',
          color: Colors.orange,
        ),
        _buildPopupMenuItem(
          value: 'delete',
          icon: Icons.delete_outline_rounded,
          label: 'Delete event',
          color: AppColors.error(context),
        ),
      ],
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

  void _edi(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EdiScreen(
          event: event,
          oUpdated: () {
            _loadEvents();
            SnackbarHelper.showSuccess(context, 'event updated successfully!');
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(EventModel event, EventProvider eventProvider) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Delete event?',
      message: 'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (result == true) {
      _delete(event, eventProvider);
    }
  }

  Future<void> _delete(EventModel event, EventProvider eventProvider) async {
    try {
      await eventProvider.delete(event.eventId);
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, 'event deleted successfully');
      _loadEvents();
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to delete event: $e');
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _navigateToCreat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEventScreen()),
    ).then((_) => _loadEvents());
  }

  void _viewDetails(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(eventId: event.eventId),
      ),
    );
  }

  Future<void> _join(
      EventModel event,
      EventProvider eventProvider,
      AppAuthProvider _authProvider) async {
    try {
      await eventProvider.join(
        event,
        _authProvider.user!.uid,
        _authProvider.user!.displayName ?? 'Member',
        _authProvider.user!.email,
        _authProvider.user!.communityId!,
      );
      SnackbarHelper.showSuccess(context, 'Joined ${event.title}');
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to join: $e');
    }
  }

  Future<void> _leave(
      EventModel event,
      EventProvider eventProvider,
      AppAuthProvider _authProvider) async {
    final confirm = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Leave event?',
      message: 'Are you sure you want to leave ${event.title}?',
      confirmLabel: 'Yes, Leave',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await eventProvider.leave(event.eventId, _authProvider.user!.uid);
        if (!mounted) return;
        SnackbarHelper.showInfo(context, 'Left ${event.title}');
      } catch (e) {
        SnackbarHelper.showError(context, 'Failed to leave: $e');
      }
    }
  }

  Widget _buildStatusBadge(EventModel event, double progress, int daysLeft) {
    String statusText;
    Color statusColor;
    
    if (event.isCompleted) {
      statusText = 'Completed';
      statusColor = Colors.green;
    } else if (daysLeft < 0) {
      statusText = 'Expired';
      statusColor = Colors.grey;
    } else if (daysLeft <= 3) {
      statusText = 'Urgent';
      statusColor = Colors.red;
    } else if (progress >= 0.8) {
      statusText = 'Almost There';
      statusColor = Colors.orange;
    } else {
      statusText = 'Active';
      statusColor = Colors.blue;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: statusColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary(context).withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Color _geColor(String type) {
    switch (type.toLowerCase()) {
      case 'savings': return Colors.green;
      case 'investment': return Colors.blue;
      case 'loan': return Colors.purple;
      case 'emergency': return Colors.red;
      default: return const Color(0xFF00BFA5);
    }
  }

  Widget _buildActiveFilterChips() {
    final hasStatusFilter = _filters.statusFilter != StatusFilter.all;
    final hasTeventTypeFilter = _filters.eventType != null;
    
    if (!hasStatusFilter && !hasTeventTypeFilter) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        color: AppColors.background(context),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (hasStatusFilter)
                _buildActiveChip(
                  _filters.statusFilter.name.toUpperCase(),
                  () => setState(() => _filters = _filters.copyWith(statusFilter: StatusFilter.all)),
                ),
              if (hasStatusFilter && hasTeventTypeFilter) const SizedBox(width: 8),
              if (hasTeventTypeFilter)
                _buildActiveChip(
                  EventTypes.getDisplayName(_filters.eventType!),
                  () => setState(() => _filters = _filters.copyWith(cleaTeventType: true)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onDeleted) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(context),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDeleted,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Shimmer.fromColors(
        baseColor: AppColors.card(context),
        highlightColor: AppColors.background(context),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

class FilterSheet extends StatefulWidget {
  final Filters filters;
  final Function(Filters) onFiltersChanged;

  const FilterSheet({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Filters _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.filters;
  }

  @override
  Widget build(BuildContext context) {
    // Access the modal's internal animation for custom cross-fades/slides
    final animation = ModalRoute.of(context)?.animation;
    
    Widget content = Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header with Ttitle and Reset Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Events',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary(context),
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final freshhhFilters = Filters();
                    setState(() {
                      _currentFilters = freshhhFilters;
                    });
                    widget.onFiltersChanged(freshhhFilters);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error(context),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters Content Area
            _buildSection('Status', _buildStatusFilter()),
            const SizedBox(height: 24),
            _buildSection('event Categories', _builTeventTypeFilter()),
            const SizedBox(height: 32),
            
            // Primary Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onFiltersChanged(_currentFilters);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (animation == null) return content;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            )),
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statusChip('All', StatusFilter.all),
        _statusChip('Ongoing', StatusFilter.ongoing),
        _statusChip('Completed', StatusFilter.completed),
      ],
    );
  }

  Widget _statusChip(String label, StatusFilter status) {
    final isSelected = _currentFilters.statusFilter == status;
    final primaryColor = AppColors.primary(context);
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isSelected) {
            _currentFilters = _currentFilters.copyWith(statusFilter: StatusFilter.all);
          } else {
            _currentFilters = _currentFilters.copyWith(statusFilter: status);
          }
        });
      },
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary(context),
      ),
      backgroundColor: AppColors.card(context),
      selectedColor: primaryColor,
      elevation: isSelected ? 4 : 0,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      pressElevation: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppColors.border(context).withValues(alpha: 0.5),
        ),
      ),
      showCheckmark: false,
    );
  }


  Widget _builTeventTypeFilter() {
    final types = ['all', ...EventTypes.allTypes];
    
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((type) {
        final isSelected = _currentFilters.eventType == type || 
                          (type == 'all' && _currentFilters.eventType == null);
        final primaryColor = AppColors.primary(context);
        
        return ChoiceChip(
          label: Text(type == 'all' ? 'All' : EventTypes.getDisplayName(type)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (type == 'all') {
                _currentFilters = _currentFilters.copyWith(cleaTeventType: true);
              } else {
                // If clicking an already selected chip, toggle it off to 'all'
                if (isSelected) {
                  _currentFilters = _currentFilters.copyWith(cleaTeventType: true);
                } else {
                  _currentFilters = _currentFilters.copyWith(eventType: type);
                }
              }
            });
          },
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
          backgroundColor: AppColors.card(context),
          selectedColor: primaryColor,
          elevation: isSelected ? 4 : 0,
          shadowColor: primaryColor.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelected ? Colors.transparent : AppColors.border(context).withValues(alpha: 0.5),
            ),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildCompactToggle(String title, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.5),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
        subtitle: Text(
          value ? 'Active' : 'Disabled',
          style: TextStyle(
            fontSize: 12,
            color: value ? AppColors.primary(context) : AppColors.textTertiary(context),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}







