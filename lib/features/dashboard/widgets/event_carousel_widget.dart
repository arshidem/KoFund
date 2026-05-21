// lib/features/dashboard/widgets/event_carousel_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:kofund/core/utils/snackbar_helper.dart';

class CarouselWidget extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback? onSeeAll;

  const CarouselWidget({
    super.key,
    required this.isAdmin,
    this.onSeeAll,
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
    final eventProvider = context.read<EventProvider>();
    final user = context.read<AppAuthProvider>().user;
    if (user != null &&
        user.communityId != null &&
        eventProvider.events.isNotEmpty &&
        eventProvider.events.first.communityId == user.communityId) {
      _isLoading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuthAndLoadData());
  }

  void _checkAuthAndLoadData() {
    if (!mounted) return;
    final user = context.read<AppAuthProvider>().user;
    final eventProvider = context.read<EventProvider>();

    if (user == null) {
      setState(() { _isLoading = false; _hasError = true; _errorMessage = 'Please sign in to view events'; });
      eventProvider.clearAllData();
      return;
    }
    if (user.communityId == null || user.communityId!.isEmpty) {
      setState(() { _isLoading = false; _hasError = true; _errorMessage = 'You are not part of any community'; });
      return;
    }
    _loadEventsData(user.communityId!);
  }

  Future<void> _loadEventsData(String communityId) async {
    if (!mounted) return;
    final eventProvider = context.read<EventProvider>();
    final authProvider = context.read<AppAuthProvider>();

    final hasExistingData = eventProvider.events.isNotEmpty &&
        eventProvider.events.first.communityId == communityId;

    setState(() {
      _isLoading = !hasExistingData;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await eventProvider.loadEvents(communityId);
      if (authProvider.user != null) {
        await eventProvider.loadMyParticipations(authProvider.user!.uid, communityId);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (error) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; _errorMessage = 'Failed to load events'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final user = context.watch<AppAuthProvider>().user;
    return _buildContent(user, isDarkMode);
  }

  void _navigateToAll(BuildContext context) {
    if (widget.onSeeAll != null) {
      widget.onSeeAll!();
      return;
    }
    final user = context.read<AppAuthProvider>().user;
    if (user == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AllEventsScreen(isAdmin: widget.isAdmin)));
  }

  Widget _buildContent(UserModel? user, bool isDarkMode) {
    if (user == null) return _buildEmptyState(icon: Icons.login_rounded, title: 'Sign in to View Events', message: 'Please sign in to see community events', isDarkMode: isDarkMode);
    if (user.communityId == null || user.communityId!.isEmpty) return _buildEmptyState(icon: Icons.group_outlined, title: 'No Community', message: 'Join a community to view events', isDarkMode: isDarkMode);
    if (_isLoading) return _buildLoadingState(isDarkMode);
    if (_hasError) return _buildErrorState(isDarkMode);

    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        final active = eventProvider.events
            .where((e) => e.isOngoing && !e.isMonthlyPayment && e.communityId == user.communityId)
            .toList();

        if (active.isEmpty) {
          return _buildEmptyState(icon: Icons.event_note_rounded, title: 'No Active Events', message: 'Check back later for new events', isDarkMode: isDarkMode);
        }

        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary(context)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Events', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
                          Text('${active.length} event${active.length == 1 ? '' : 's'} running', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                        ],
                      ),
                    ),
                    if (active.length >= 2)
                      GestureDetector(
                        onTap: () => _navigateToAll(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.25)),
                          ),
                          child: Text('See all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary(context))),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Carousel ─────────────────────────────────────────────
              SizedBox(
                height: 280,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: active.length,
                  padEnds: true,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _DashboardCard(event: active[index], isAdmin: widget.isAdmin, isDarkMode: isDarkMode),
                  ),
                ),
              ),

              // ── Page dots ────────────────────────────────────────────
              if (active.length > 1) ...[
                const SizedBox(height: 10),
                _PageDots(controller: _pageController, count: active.length),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message, required bool isDarkMode}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
          child: Row(
            children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.textTertiary(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 8),
              Container(width: 110, height: 14, decoration: BoxDecoration(color: AppColors.textTertiary(context).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.94),
            itemCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, __) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: EventCardSkeleton(isDarkMode: isDarkMode)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 32, color: AppColors.error(context)),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage ?? 'Failed to load events', style: TextStyle(fontSize: 13, color: AppColors.error(context)))),
          TextButton(onPressed: _checkAuthAndLoadData, child: Text('Retry', style: TextStyle(color: AppColors.primary(context), fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _PageDots extends StatefulWidget {
  final PageController controller;
  final int count;
  const _PageDots({required this.controller, required this.count});

  @override
  State<_PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<_PageDots> {
  double _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) setState(() => _page = widget.controller.page ?? 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (i) {
        final selected = (i - _page).abs() < 0.5;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary(context)
                : AppColors.textSecondary(context).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
        );
      }),
    );
  }
}

class _DashboardCard extends StatefulWidget {
  final EventModel event;
  final bool isAdmin;
  final bool isDarkMode;

  const _DashboardCard({required this.event, required this.isAdmin, required this.isDarkMode});

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isJoining = false;
  bool _isLeaving = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppAuthProvider>().user;

    return Selector<EventProvider, bool>(
      selector: (_, p) => user != null ? p.hasUserJoined(widget.event.eventId, user.uid) : false,
      builder: (context, hasJoined, _) {
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        final canJoin = widget.event.canJoin && !hasJoined;
        return _buildModernCard(context, user, hasJoined, canJoin, eventProvider, authProvider);
      },
    );
  }

  Widget _buildModernCard(BuildContext context, UserModel? user, bool hasJoined, bool canJoin, EventProvider eventProvider, AppAuthProvider authProvider) {
    final primaryColor = AppColors.primary(context);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.15 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    ),
                    child: Icon(EventTypes.getIconData(widget.event.eventType), size: 24, color: primaryColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context), letterSpacing: -0.4),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (!widget.event.isMonthlyPayment && widget.event.eventDate != null) ...[
                              Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textSecondary(context)),
                              const SizedBox(width: 4),
                              Text(_formatDate(widget.event.eventDate!), style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), fontWeight: FontWeight.w500)),
                              const SizedBox(width: 12),
                            ],
                            Icon(Icons.group_rounded, size: 12, color: AppColors.textSecondary(context)),
                            const SizedBox(width: 4),
                            StreamBuilder<int>(
                              stream: eventProvider.streamParticipantCount(widget.event.eventId, communityId: widget.event.communityId),
                              builder: (context, snap) {
                                final count = snap.data ?? widget.event.currentParticipants;
                                final max = widget.event.maxParticipants;
                                final isFull = widget.event.isFixedParticipants && count >= max;
                                return Text(
                                  '$count${widget.event.isFixedParticipants ? '/$max' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isFull ? AppColors.error(context) : AppColors.textSecondary(context),
                                    fontWeight: isFull ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              StreamBuilder<Map<String, dynamic>>(
                stream: eventProvider.streamProgress(widget.event.eventId, communityId: widget.event.communityId),
                builder: (context, snap) {
                  final d = snap.data ?? {'collected': 0.0, 'target': 100.0, 'percentage': 0.0};
                  final pct = (d['percentage'] as num).toDouble().clamp(0.0, 1.0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fund Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                          Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: AppColors.progressBackground(context),
                          color: primaryColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.background(context).withValues(alpha: widget.isDarkMode ? 0.4 : 0.6),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                ),
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: eventProvider.streamFinancialSummary(widget.event.eventId, communityId: widget.event.communityId),
                  builder: (context, snap) {
                    final s = snap.data ?? {'collected': 0.0, 'expenses': 0.0, 'balance': 0.0};
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCleanStat('Collected', s['collected'], AppColors.textSecondary(context)),
                        Container(width: 1, height: 24, color: AppColors.border(context)),
                        _buildCleanStat('Expenses', s['expenses'], AppColors.textSecondary(context)),
                        Container(width: 1, height: 24, color: AppColors.border(context)),
                        _buildCleanStat('Balance', s['balance'], primaryColor, isBold: true),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _viewDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary(context),
                        side: BorderSide(color: AppColors.border(context), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('View Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (hasJoined)
                     _leaveButton(eventProvider, authProvider)
                  else
                    Expanded(child: _joinButton(canJoin, eventProvider, authProvider)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanStat(String label, dynamic value, Color titleColor, {bool isBold = false}) {
    final numValue = (value as num).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary(context))),
        const SizedBox(height: 4),
        Text('₹${numValue.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w800 : FontWeight.w700, color: titleColor)),
      ],
    );
  }

  Widget _leaveButton(EventProvider eventProvider, AppAuthProvider authProvider) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border(context), width: 1.5),
      ),
      child: IconButton(
        icon: _isLeaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.red)))
            : const Icon(Icons.logout_rounded, size: 20, color: Colors.red),
        onPressed: _isLeaving ? null : () => _leave(eventProvider, authProvider),
        tooltip: 'Leave Event',
      ),
    );
  }

  Widget _joinButton(bool canJoin, EventProvider eventProvider, AppAuthProvider authProvider) {
    return ElevatedButton(
      onPressed: canJoin ? () => _join(eventProvider, authProvider) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canJoin ? AppColors.primary(context) : AppColors.textTertiary(context),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
      ),
      child: _isJoining
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
          : Text(
              !canJoin && widget.event.isFixedParticipants && widget.event.currentParticipants >= widget.event.maxParticipants
                  ? 'Event Full'
                  : 'Join Event',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
    );
  }

  Future<void> _join(EventProvider eventProvider, AppAuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;
    setState(() => _isJoining = true);
    try {
      await eventProvider.join(widget.event, user.uid, user.displayName ?? user.email, user.email, widget.event.communityId);
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, 'Joined ${widget.event.title} successfully');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Failed to join: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _leave(EventProvider eventProvider, AppAuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;
    final confirm = await DialogHelper.showConfirmationDialog(context, title: 'Leave event?', message: 'Are you sure you want to leave ${widget.event.title}?', confirmLabel: 'Leave', icon: Icons.exit_to_app_rounded, isDestructive: true);
    if (confirm == true) {
      HapticHelper.success();
      setState(() => _isLeaving = true);
      try {
        await eventProvider.leave(widget.event.eventId, user.uid, communityId: widget.event.communityId);
        if (!mounted) return;
        SnackbarHelper.showSuccess(context, 'Left ${widget.event.title}');
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        SnackbarHelper.showError(context, 'Failed to leave: $e');
      } finally {
        if (mounted) setState(() => _isLeaving = false);
      }
    }
  }

  void _viewDetails() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: widget.event.eventId)));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nowOnly = DateTime(now.year, now.month, now.day);
    final diff = dateOnly.difference(nowOnly).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return 'In $diff days';
    if (diff < 0 && diff > -7) return '${(-diff)} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
