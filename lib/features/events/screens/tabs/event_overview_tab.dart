import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../models/event_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../providers/event_provider.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../auth/models/user_model.dart';
import 'package:kofund/core/services/user_service.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/milestone_celebration_overlay.dart';
import '../../../../core/utils/event_report_generator.dart';
import '../../../community/providers/community_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class EventOverviewTab extends StatefulWidget {
  final EventModel event;

  const EventOverviewTab({super.key, required this.event});

  @override
  State<EventOverviewTab> createState() => _EventOverviewTabState();
}

class _EventOverviewTabState extends State<EventOverviewTab> {
  final GlobalKey<MilestoneCelebrationOverlayState> _celebrationKey = GlobalKey();
  double _previousProgress = 0.0;
  static const List<double> _milestones = [50.0, 75.0, 100.0];
  bool _isExporting = false;
  double? _cachedTotalCollected;
  double? _cachedTotalExpenses;
  int? _cachedParticipantCount;

  // Cache streams to prevent re-creation on every rebuild
  Stream<double>? _contributionsStream;
  Stream<double>? _expensesStream;
  Stream<int>? _participantCountStream;

  void _onRefresh() {
    setState(() {});
  }

  /// Checks if progress has crossed a milestone threshold and triggers celebration.
  void _checkMilestone(double currentProgress) {
    for (final milestone in _milestones) {
      if (_previousProgress < milestone && currentProgress >= milestone) {
        debugPrint('🎉 Milestone reached: ${milestone.toInt()}%');
        _celebrationKey.currentState?.triggerCelebration();
        break; // Only trigger once per update
      }
    }
    _previousProgress = currentProgress;
  }

  Future<void> _handleExport({
    required ContributionProvider contributionProvider,
    required ExpenseProvider expenseProvider,
    required ParticipantProvider participantProvider,
  }) async {
    setState(() => _isExporting = true);
    HapticHelper.medium();

    try {
      // Fetch all necessary data
      final participants = await participantProvider
          .streamEventParticipants(widget.event.eventId, communityId: widget.event.communityId)
          .first;
      final contributions = await contributionProvider
          .getContributions(widget.event.eventId, communityId: widget.event.communityId);
      final expenses = await expenseProvider
          .getEventExpenses(widget.event.eventId, communityId: widget.event.communityId);

      if (!mounted) return;

      await EventReportGenerator.generateAndShowPreview(
        context: context,
        event: widget.event,
        participants: participants,
        expenses: expenses,
        contributions: contributions,
        communityName: Provider.of<CommunityProvider>(context, listen: false).currentCommunity?.name,
      );
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to generate report: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final participantProvider = Provider.of<ParticipantProvider>(context);
    final _userService = Provider.of<UserService>(context, listen: false);
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    
    final bool isOrganizer = authProvider.user?.uid == widget.event.createdBy || 
                           (authProvider.user?.isAdmin ?? false);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          CustomScrollView(
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100), // Extra bottom padding for floating button
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildFinancialSummaryCard(
                      context,
                      contributionProvider,
                      expenseProvider,
                      participantProvider,
                    ),
                    const SizedBox(height: 12),
                    _builHeader(context, participantProvider, isOrganizer),
                    const SizedBox(height: 12),
                    _builInfoCard(context, participantProvider, _userService),
                    const SizedBox(height: 12),
                    _builStatusCard(context, participantProvider),

                  ]),
                ),
              ),
            ],
          ),
          
          // Floating Action Buttons (Export & Link)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: _buildFloatingActions(
              context,
              contributionProvider,
              expenseProvider,
              participantProvider,
              isOrganizer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _builHeader(
    BuildContext context,
    ParticipantProvider participantProvider,
    bool isOrganizer,
  ) {
    return StreamBuilder<List<ParticipantModel>>(
      stream: participantProvider.streamEventParticipants(widget.event.eventId, communityId: widget.event.communityId),
      builder: (context, snapshot) {
        final participants = snapshot.data ?? [];
        final participantCount = participants.length;

        final isFull = widget.event.participantType == 'fixed' &&
            participantCount >= widget.event.maxParticipants;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border(context)),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(0, 2),
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeaderInfoTile(
                context,
                icon: Icons.people_alt_rounded,
                title: 'Participants',
                value: widget.event.participantType == 'fixed'
                    ? '$participantCount / ${widget.event.maxParticipants}'
                    : '$participantCount',
                valueColor: isFull ? AppColors.error(context) : AppColors.primary(context),
              ),
              const SizedBox(height: 10),
              GridView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.8,
                ),
                children: [
                  if (!widget.event.isMonthlyPayment && widget.event.eventDate != null)
                    _buildHeaderInfoTile(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: 'Date',
                      value: DateFormat('MMM dd, yyyy').format(widget.event.eventDate!),
                      valueColor: AppColors.primary(context),
                    ),
                  _buildHeaderInfoTile(
                    context,
                    icon: Icons.monetization_on_rounded,
                    title: 'Contribution',
                    value: widget.event.suggestedContribution != null
                        ? '₹${widget.event.suggestedContribution!.toStringAsFixed(0)}'
                        : 'Flexible',
                    valueColor: widget.event.suggestedContribution != null
                        ? AppColors.textPrimary(context)
                        : AppColors.textSecondary(context),
                  ),
                  _buildHeaderInfoTile(
                    context,
                    icon: Icons.flag_rounded,
                    title: 'Status',
                    value: widget.event.isActive
                        ? 'Active'
                        : widget.event.isCompleted
                            ? 'Completed'
                            : 'Inactive',
                    valueColor: widget.event.isActive
                        ? AppColors.primary(context)
                        : widget.event.isCompleted
                            ? AppColors.textTertiary(context)
                            : AppColors.error(context),
                  ),
                  if (!widget.event.isMonthlyPayment)
                    _buildHeaderInfoTile(
                      context,
                      icon: Icons.assessment_rounded,
                      title: 'Estimated Total',
                      value: _calculateEstimatedTotal(widget.event, participantCount),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _builInfoCard(
    BuildContext context,
    ParticipantProvider participantProvider,
    UserService _userService,
  ) {
    return Card(
      color: AppColors.card(context),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border(context), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary(context)),
                const SizedBox(width: 8),
                Text(
                  'Event Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.event.eventDate != null && !widget.event.isMonthlyPayment)
              _buildDetailTile(
                context,
                icon: Icons.calendar_today_rounded,
                label: 'Event Date',
                value: DateFormat('EEEE, MMMM dd, yyyy').format(widget.event.eventDate!),
              ),
            const SizedBox(height: 12),
            if (widget.event.suggestedContribution != null)
              _buildDetailTile(
                context,
                icon: Icons.monetization_on_rounded,
                label: 'Suggested Contribution',
                value: '₹ ${widget.event.suggestedContribution!.toStringAsFixed(0)} per person',
              ),
            const SizedBox(height: 12),
            if (widget.event.totalAmount != null && !widget.event.isMonthlyPayment)
              _buildDetailTile(
                context,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Total Event Budget',
                value: '₹ ${widget.event.totalAmount!.toStringAsFixed(0)}',
              ),
            if (!widget.event.isMonthlyPayment) const SizedBox(height: 12),
            if (!widget.event.isMonthlyPayment)
              StreamBuilder<int>(
                stream: participantProvider.streamEventParticipantCount(widget.event.eventId, communityId: widget.event.communityId),
                builder: (context, snapshot) {
                  final participantCount = snapshot.data ?? 0;
                  return _buildDetailTile(
                    context,
                    icon: Icons.assessment_rounded,
                    label: 'Estimated Total Collection',
                    value: _calculateEstimatedTotal(widget.event, participantCount),
                  );
                },
              ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: participantProvider.streamEventParticipantCount(widget.event.eventId, communityId: widget.event.communityId),
              builder: (context, snapshot) {
                final participantCount = snapshot.data ?? 0;
                return _buildDetailTile(
                  context,
                  icon: Icons.people_alt_rounded,
                  label: 'Participant Capacity',
                  value: widget.event.participantType == 'fixed'
                      ? '$participantCount / ${widget.event.maxParticipants} participants'
                      : 'Unlimited (Currently $participantCount joined)',
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<UserModel?>(
              future: _userService.getUserById(widget.event.createdBy),
              builder: (context, snapshot) {
                String displayValue = widget.event.createdBy;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  displayValue = 'Loading...';
                } else if (snapshot.hasData && snapshot.data != null) {
                  final user = snapshot.data!;
                  displayValue = user.displayName ?? user.email;
                }
                return _buildDetailTile(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: 'Organized By',
                  value: displayValue,
                );
              },
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              context,
              icon: Icons.groups_rounded,
              label: 'Participant type',
              value: widget.event.participantType == 'fixed' ? 'Fixed (Limited slots)' : 'Unlimited (Open for all)',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.event.status, context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _getStatusColor(widget.event.status, context).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(widget.event.status), size: 18, color: _getStatusColor(widget.event.status, context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Event Status', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        const SizedBox(height: 2),
                        Text(widget.event.status.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _getStatusColor(widget.event.status, context))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(BuildContext context, {required IconData icon, required String label, required String value, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary(context).withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 18, color: AppColors.primary(context))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary(context))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _showShareMenu(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.link_rounded,
              size: 20,
              color: AppColors.primary(context),
            ),
          ),
          tooltip: 'Get Web Link',
        ),
      ],
    );
  }

  void _showShareMenu(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    bool isPublic = widget.event.isPublicEnabled;
    String? password = widget.event.publicPassword;
    final TextEditingController passwordController = TextEditingController(text: password);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final String eventPublicLink = 'https://kofund-153ba.web.app/s/${widget.event.eventId}';
          
          // Check if anything has changed compared to the original event data
          final bool hasChanges = isPublic != widget.event.isPublicEnabled || 
                                 passwordController.text != (widget.event.publicPassword ?? '');
          final bool isValidPassword = passwordController.text.isEmpty || passwordController.text.length >= 4;
          final bool canSave = hasChanges && isValidPassword;
          
          return Container(
            padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 40),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Share Event',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Public Sharing Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.public_rounded, size: 20, color: AppColors.primary(context)),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Public Sharing',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  Text(
                                    'Allow anyone to view this event',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: isPublic,
                            activeColor: AppColors.primary(context),
                            onChanged: (value) {
                              setModalState(() => isPublic = value);
                            },
                          ),
                        ],
                      ),
                      
                      if (isPublic) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textSecondary(context)),
                                const SizedBox(width: 8),
                                Text(
                                  'Access Password (Optional)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              onChanged: (value) => setModalState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Enter password',
                                errorText: passwordController.text.isNotEmpty && passwordController.text.length < 4
                                    ? 'Minimum 4 characters required'
                                    : null,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                  borderSide: BorderSide(color: AppColors.primary(context)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                if (isPublic) ...[
                  Text(
                    'Public Link',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            eventPublicLink,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary(context),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Copy Button
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: eventPublicLink));
                            SnackbarHelper.showInfo(context, 'Link copied!');
                          },
                          icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.primary(context)),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Copy Link',
                        ),
                        // Share Button
                        IconButton(
                          onPressed: () {
                            Share.share(
                              'Check out "${widget.event.title}" on KoFund:\n$eventPublicLink',
                              subject: widget.event.title,
                            );
                          },
                          icon: Icon(Icons.share_rounded, size: 18, color: AppColors.primary(context)),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Share Link',
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),

                // Save Changes Button at the bottom
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!canSave || isSaving) ? null : () async {
                      setModalState(() => isSaving = true);
                      final pwd = passwordController.text;
                      try {
                        await eventProvider.update(widget.event.copyWith(
                          isPublicEnabled: isPublic,
                          publicPassword: pwd.isEmpty ? null : pwd,
                        ));
                        if (context.mounted) {
                          SnackbarHelper.showSuccess(context, 'Settings saved successfully!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          SnackbarHelper.showError(context, 'Failed to save: $e');
                        }
                      } finally {
                        setModalState(() => isSaving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSave ? AppColors.primary(context) : AppColors.textSecondary(context).withValues(alpha: 0.1),
                      foregroundColor: canSave ? Colors.white : AppColors.textSecondary(context),
                      disabledBackgroundColor: isSaving ? AppColors.primary(context).withValues(alpha: 0.7) : null,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: hasChanges ? 2 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            hasChanges ? 'Save Changes' : 'Saved', 
                            style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textSecondary.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  /// Shimmer placeholder for the financial card while streams are loading
  Widget _buildFinancialShimmer(bool isDark) {
    final shimmerColor = Colors.white.withValues(alpha: isDark ? 0.15 : 0.25);
    final secondaryShimmerColor = Colors.white.withValues(alpha: isDark ? 0.1 : 0.2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120, height: 14,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 180, height: 32,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 80, height: 18, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 6),
                  Container(width: 60, height: 12, decoration: BoxDecoration(color: secondaryShimmerColor, borderRadius: BorderRadius.circular(6))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 80, height: 18, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 6),
                  Container(width: 60, height: 12, decoration: BoxDecoration(color: secondaryShimmerColor, borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard(BuildContext context, ContributionProvider contributionProvider, ExpenseProvider expenseProvider, ParticipantProvider participantProvider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Cache streams so they survive rebuilds
    _contributionsStream ??= contributionProvider.streamTotalContributions(widget.event.eventId, communityId: widget.event.communityId);
    _expensesStream ??= expenseProvider.streamEventTotalExpenses(widget.event.eventId, communityId: widget.event.communityId);
    _participantCountStream ??= participantProvider.streamEventParticipantCount(widget.event.eventId, communityId: widget.event.communityId);

    return StreamBuilder<double>(
      initialData: _cachedTotalCollected,
      stream: _contributionsStream,
      builder: (context, contributionSnapshot) {
        // Only update cache with non-zero values to avoid losing data when offline
        if (contributionSnapshot.hasData && (contributionSnapshot.data ?? 0) > 0) {
          _cachedTotalCollected = contributionSnapshot.data;
        } else if (_cachedTotalCollected == null && contributionSnapshot.hasData) {
          _cachedTotalCollected = contributionSnapshot.data;
        }
        
        // Wait for contributions to load before showing the card
        // This prevents a brief flash of "-₹expense" while contributions are still loading
        final totalCollected = _cachedTotalCollected ?? contributionSnapshot.data ?? 0.0;
        final bool contributionsReady = _cachedTotalCollected != null || contributionSnapshot.hasData || totalCollected > 0;
        
        return StreamBuilder<double>(
          initialData: _cachedTotalExpenses,
          stream: _expensesStream,
          builder: (context, expenseSnapshot) {
            if (expenseSnapshot.hasData && (expenseSnapshot.data ?? 0) > 0) {
              _cachedTotalExpenses = expenseSnapshot.data;
            } else if (_cachedTotalExpenses == null && expenseSnapshot.hasData) {
              _cachedTotalExpenses = expenseSnapshot.data;
            }
            final totalExpenses = _cachedTotalExpenses ?? expenseSnapshot.data ?? 0.0;
            
            // Show shimmer if contributions haven't loaded yet (expenses may have loaded first)
            if (!contributionsReady && totalExpenses > 0) {
              return _buildFinancialShimmer(isDark);
            }
            
            final balanceAamount = totalCollected - totalExpenses;
            return StreamBuilder<int>(
              initialData: widget.event.currentParticipants,
              stream: _participantCountStream,
              builder: (context, participantSnapshot) {
                if (participantSnapshot.hasData && (participantSnapshot.data ?? 0) > 0) {
                  _cachedParticipantCount = participantSnapshot.data;
                } else if (_cachedParticipantCount == null && participantSnapshot.hasData) {
                  _cachedParticipantCount = participantSnapshot.data;
                }
                final participantCount = _cachedParticipantCount ?? participantSnapshot.data ?? widget.event.currentParticipants;
                final double totalExpected = widget.event.isMonthlyPayment 
                    ? 0.0 
                    : ((widget.event.totalAmount ?? 0.0) > 0 ? widget.event.totalAmount! : (widget.event.suggestedContribution ?? 0.0) * (participantCount > 0 ? participantCount : (widget.event.isFixedParticipants ? widget.event.maxParticipants : 1)));
                final progressPercentage = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0.0;

                // Check for milestone crossing
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkMilestone(progressPercentage);
                });

                return MilestoneCelebrationOverlay(
                  key: _celebrationKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                        Text(
                          "Financial Summary",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "₹${balanceAamount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem(
                              "Total Collected",
                              "₹${totalCollected.toStringAsFixed(2)}",
                              Colors.white,
                              Colors.white.withValues(alpha: 0.7),
                            ),
                            _buildStatItem(
                              "Total Expenses",
                              "₹${totalExpenses.toStringAsFixed(2)}",
                              Colors.white,
                              Colors.white.withValues(alpha: 0.7),
                            ),
                          ],
                        ),

                        if (totalExpected > 0) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              Text('Collection Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))), 
                              Text('₹${totalCollected.toStringAsFixed(0)} / ₹${totalExpected.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white))
                            ]
                          ),

                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10), 
                            child: LinearProgressIndicator(
                              value: (totalCollected / totalExpected).clamp(0, 1), 
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.2), 
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
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
      },
    );
  }

  Widget _builStatusCard(BuildContext context, ParticipantProvider participantProvider) {
    return Container(); // Placeholder for other status elements if needed
  }

  String _calculateEstimatedTotal(EventModel event, int participantCount) {
    double total = (event.totalAmount ?? 0.0) > 0 ? event.totalAmount! : (event.suggestedContribution ?? 0.0) * (participantCount > 0 ? participantCount : (event.isFixedParticipants ? event.maxParticipants : 1));
    return '₹${total.toStringAsFixed(0)}';
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'active': return Colors.green;
      case 'completed': return AppColors.primary(context);
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Icons.play_arrow_rounded;
      case 'completed': return Icons.check_circle_rounded;
      default: return Icons.info_rounded;
    }
  }

  Widget _buildFloatingActions(
    BuildContext context,
    ContributionProvider contributionProvider,
    ExpenseProvider expenseProvider,
    ParticipantProvider participantProvider,
    bool isOrganizer,
  ) {
    return Row(
      children: [
        // Export Button (Main Action)
        Expanded(
          flex: isOrganizer ? 4 : 1,
          child: ElevatedButton.icon(
            onPressed: _isExporting 
              ? null 
              : () => _handleExport(
                contributionProvider: contributionProvider,
                expenseProvider: expenseProvider,
                participantProvider: participantProvider,
              ),
            icon: _isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.share_rounded, size: 20, color: Colors.white),
            label: Text(
              _isExporting ? 'Exporting...' : 'Export Event Summary',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 6,
              shadowColor: AppColors.primary(context).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30), // Fully rounded
              ),
            ),
          ),
        ),
        
        if (isOrganizer) ...[
          const SizedBox(width: 12),
          // Link Button (Admin Action)
          Container(
            height: 58, // Match height of Export button
            width: 58,
            decoration: BoxDecoration(
              color: AppColors.primary(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary(context).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showShareMenu(context),
                borderRadius: BorderRadius.circular(30),
                child: const Icon(
                  Icons.link_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}






