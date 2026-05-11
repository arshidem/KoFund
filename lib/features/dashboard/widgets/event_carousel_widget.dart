// lib/features/dashboard/widgets/event_carousel_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/core/skeleton/event_card_skeleton.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/events/constants/event_Types.dart';
import 'package:kofund/features/events/providers/event_provider.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:kofund/features/events/screens/event_details_screen.dart';
import 'package:kofund/features/events/screens/all_events_screen.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/core/utils/haptic_helper.dart';

class CarouselWidget extends StatefulWidget {
  final bool isAdmin;

  const CarouselWidget({
    super.key,
    required this.isAdmin, // Changed from isAdmin = false to required
  });

  @override
  State<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<CarouselWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.94);
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 DEBUG: CarouselWidget initState called');
    
    // Fast-cache check to bypass the loading skeleton flash for frname 0
    final _authProvider = context.read<AppAuthProvider>();
    final eventProvider = context.read<EventProvider>();
    final user = _authProvider.user;
    
    if (user != null && user.communityId != null && 
        eventProvider.events.isNotEmpty && 
        eventProvider.events.first.communityId == user.communityId) {
      _isLoading = false;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadData();
    });
  }

  void _checkAuthAndLoadData() {
    if (!mounted) return;
    
    final _authProvider = context.read<AppAuthProvider>();
    final user = _authProvider.user;
    final eventProvider = context.read<EventProvider>();
    
    if (user == null) {
      debugPrint('❌ DEBUG: No user found in CarouselWidget');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Please sign in to view events';
        });
      }
      
      eventProvider.clearAllData();
      return;
    }
    
    if (user.communityId == null || user.communityId!.isEmpty) {
      debugPrint('❌ DEBUG: User has no community');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'You are not part of any community';
        });
      }
      return;
    }
    
    debugPrint('✅ DEBUG: User found with community ${user.communityId}, loading events...');
    _loadEventsData(user.communityId!);
  }

  Future<void> _loadEventsData(String communityId) async {
    if (!mounted) return;
    
    final eventProvider = context.read<EventProvider>();
    final _authProvider = context.read<AppAuthProvider>();
    
    // Determine if we have existing cached data for this community
    final hasExistingData = eventProvider.events.isNotEmpty && 
                            eventProvider.events.first.communityId == communityId;
    
    if (!hasExistingData) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    } else {
      // Immediately clear error states and rely on instant playback
      setState(() {
        _isLoading = false;
        _hasError = false;
        _errorMessage = null;
      });
    }
    
    try {
      // Fetch freshhh data in the background
      await eventProvider.loadEvents(communityId);
      
      if (_authProvider.user != null) {
        await eventProvider.loadMyParticipations(
          _authProvider.user!.uid,
          communityId,
        );
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('❌ DEBUG: Error loading events data: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load events';
        });
      }
    }
  }

  void _retryLoading() {
    _checkAuthAndLoadData();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final _authProvider = context.watch<AppAuthProvider>();
    final user = _authProvider.user;
    
    return _buildContent(user, isDarkMode);
  }

  void _navigateToAll(BuildContext context) {
    final _authProvider = context.read<AppAuthProvider>();
    final user = _authProvider.user;
    
    if (user == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllEventsScreen(
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  Widget _buildContent(UserModel? user, bool isDarkMode) {
    // If no user is logged in
    if (user == null) {
      return _buildEmptyState(
        icon: Icons.login_rounded,
        title: 'Sign in to View Events',
        message: 'Please sign in to see community events',
        isDarkMode: isDarkMode,
      );
    }
    
    // If user has no community
    if (user.communityId == null || user.communityId!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_outlined,
        title: 'No Community',
        message: 'Join a community to view events',
        isDarkMode: isDarkMode,
      );
    }
    
    // If loading
    if (_isLoading) {
      return _buildLoadingState(isDarkMode);
    }
    
    // If error
    if (_hasError) {
      return _buildErrorState(isDarkMode);
    }
    
    // Show events from provider
    return Consumer<EventProvider>(
    builder: (context, eventProvider, child) {
      final active = eventProvider.events
          .where((event) => 
              event.isOngoing && 
              !event.isMonthlyPayment &&
              event.communityId == user.communityId)
          .toList();

      // If no active events
      if (active.isEmpty) {
        return _buildEmptyState(
          icon: Icons.event_note_rounded,
          title: 'No Active Events',
          message: 'Check back later for new events',
          isDarkMode: isDarkMode,
        );
      }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header with icon and "See all" link
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 18,
                    color: AppColors.primary(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Active Events',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  if (active.length >= 2)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _navigateToAll(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // event carousel - CENTER THIS
// event carousel with wider cards
// event carousel with wider cards - UPDATE THE HEIGHT
SizedBox(
  height: 330,
  child: PageView.builder(
    controller: _pageController,
    itemCount: active.length,
    padEnds: true,
    physics: const BouncingScrollPhysics(),
    itemBuilder: (context, index) {
      final event = active[index];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _DashboardCard(
          event: event,
          isAdmin: widget.isAdmin,
          isDarkMode: isDarkMode,
        ),
      );
    },
  ),
),

          ],
        ),
      );
    },
  );
}

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Container(
  
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 120,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

       // Carousel skeleton with wider cards
SizedBox(
  height: 330,
  child: PageView.builder(
    controller: PageController(viewportFraction: 0.94), // Match the viewportFraction
    itemCount: 2,
    padEnds: true,
    physics: const NeverScrollableScrollPhysics(),
    itemBuilder: (context, index) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: EventCardSkeleton(isDarkMode: isDarkMode),
      );
    },
  ),
),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.error(context),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Failed to load events',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error(context),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            onTap: _retryLoading,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.3)),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Dashboard event Card
class _DashboardCard extends StatefulWidget {
  final EventModel event;
  final bool isAdmin;
  final bool isDarkMode;

  const _DashboardCard({
    required this.event,
    required this.isAdmin,
    required this.isDarkMode,
  });

  @override
  State<_DashboardCard> createState() => __DashboarCardState();
}

class __DashboarCardState extends State<_DashboardCard> {
  bool _isJoining = false;
  bool _isLeaving = false;

  @override
  Widget build(BuildContext context) {
    final _authProvider = context.watch<AppAuthProvider>();
    final user = _authProvider.user;
    
    return Selector<EventProvider, bool>(
      selector: (_, p) => user != null ? p.hasUserJoined(widget.event.eventId, user.uid) : false,
      builder: (context, hasJoined, _) {
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        final canJoin = widget.event.canJoin && !hasJoined;
        
        return _buildCardWrapper(context, user, hasJoined, canJoin, eventProvider, _authProvider);
      },
    );
  }

  Widget _buildCardWrapper(BuildContext context, UserModel? user, bool hasJoined, bool canJoin, EventProvider eventProvider, AppAuthProvider _authProvider) {
    return RepaintBoundary(
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // event header
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 12), // Reduced bottom padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // event type icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                      child: Icon(
                        EventTypes.getIconData(widget.event.eventType),
                        size: 18,
                        color: AppColors.primary(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Ttitle and participants
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.group_rounded,
                                size: 12,
                                color: AppColors.textSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              StreamBuilder<int>(
                                stream: eventProvider.streamParticipantCount(widget.event.eventId),
                                builder: (context, snapshot) {
                                  final participantCount = snapshot.data ?? widget.event.currentParticipants;
                                  final maxParticipants = widget.event.maxParticipants;
                                  final isFull = widget.event.isFixedParticipants && participantCount >= maxParticipants;
                                  
                                  return Text(
                                    "$participantCount/${widget.event.isFixedParticipants ? maxParticipants : '∞'} participants",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isFull 
                                          ? AppColors.error(context)
                                          : AppColors.textSecondary(context),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Joined badge
                    if (hasJoined)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'Joined',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Date and location
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                  if (!widget.event.isMonthlyPayment && widget.event.eventDate != null)
  Text(
    _formatDate(widget.event.eventDate!),
    style: TextStyle(
      fontSize: 11,
      color: AppColors.textSecondary(context),
    ),
  ),
                    if (widget.event.location.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border(context).withValues(alpha: 0.3),
          ),
          
          // Financial stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: eventProvider.streamFinancialSummary(widget.event.eventId),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {
                  'collected': 0.0,
                  'expenses': 0.0,
                  'balance': 0.0,
                };
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildStatItemCompact(
                        'Collected',
                        Icons.account_balance_wallet_rounded,
                        AppColors.primary(context),
                        stats['collected'] ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatItemCompact(
                        'Expenses',
                        Icons.money_off_rounded,
                        AppColors.primary(context),
                        stats['expenses'] ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatItemCompact(
                        'Balance',
                        Icons.savings_rounded,
                        AppColors.primary(context),
                        stats['balance'] ?? 0.0,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border(context).withValues(alpha: 0.3),
          ),
          
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: eventProvider.streamProgress(widget.event.eventId),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {
                  'collected': 0.0,
                  'target': 100.0,
                  'percentage': 0.0,
                };
                
                final collected = (data['collected'] as num).toDouble();
                final target = (data['target'] as num).toDouble();
                final progress = (data['percentage'] as num).toDouble();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.progressBackground(context),
                        color: AppColors.progressFill(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${collected.toStringAsFixed(0)} of ₹${target.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Action buttons - ADD THIS TO FILL REMAINING SPACE
          const Spacer(),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Added bottom padding
            child: Row(
              children: [
                // View Details button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewDetails(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(context),
                      side: BorderSide(
                        color: AppColors.border(context),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Join/Leave button
                if (hasJoined)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(
                        color:Colors.red.withValues(alpha: 0.3) ,
                      ),
                    ),
                    child: IconButton(
                      icon: _isLeaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            )
                          : const Icon(
                              Icons.exit_to_app_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                      onPressed: _isLeaving ? null : () => _leave(eventProvider, _authProvider),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canJoin ? () => _join(eventProvider, _authProvider) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canJoin
                            ? AppColors.primary(context)
                            : AppColors.textTertiary(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: _isJoining
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              !canJoin && widget.event.isFixedParticipants && 
                              widget.event.currentParticipants >= widget.event.maxParticipants
                                  ? 'event Full'
                                  : 'Join Now',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildStatItemCompact(
    String label,
    IconData icon,
    Color color,
    double value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${value.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _join(EventProvider eventProvider, AppAuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isJoining = true);

    try {
      await eventProvider.join(
        widget.event,
        user.uid,
        user.displayName ?? user.email,
        user.email,
        widget.event.communityId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${widget.event.title} successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  Future<void> _leave(EventProvider eventProvider, AppAuthProvider _authProvider) async {
    final user = _authProvider.user;
    if (user == null) return;

    final confirm = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Leave event?',
      message: 'Are you sure you want to leave ${widget.event.title}?',
      confirmLabel: 'Leave',
      icon: Icons.exit_to_app_rounded,
      isDestructive: true,
    );

    if (confirm == true) {
      HapticHelper.success();
      setState(() => _isLeaving = true);

      try {
        await eventProvider.leave(widget.event.eventId, user.uid);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left ${widget.event.title}'),
            backgroundColor: Colors.green,
          ),
        );
        
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLeaving = false);
      }
    }
  }

  void _viewDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(eventId: widget.event.eventId),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return 'In ${difference.inDays} days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}







