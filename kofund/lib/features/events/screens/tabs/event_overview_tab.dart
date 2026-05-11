import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/event_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../auth/models/user_model.dart';
import 'package:kofund/core/services/user_service.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/milestone_celebration_overlay.dart';
import '../../../../core/utils/event_report_generator.dart';
import '../../../community/providers/community_provider.dart';

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
          .streamEventParticipants(widget.event.eventId)
          .first;
      final contributions = await contributionProvider
          .getContributions(widget.event.eventId);
      final expenses = await expenseProvider
          .getEventExpenses(widget.event.eventId);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
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
                    const SizedBox(height: 16),
                    _builHeader(context, participantProvider),
                    const SizedBox(height: 16),
                    _builInfoCard(context, participantProvider, _userService),
                    const SizedBox(height: 16),
                    _builStatusCard(context, participantProvider),

                  ]),
                ),
              ),
            ],
          ),
          
          // Floating Export Button
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: _buildExportButton(
              context,
              contributionProvider,
              expenseProvider,
              participantProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _builHeader(
    BuildContext context,
    ParticipantProvider participantProvider,
  ) {
    return StreamBuilder<List<ParticipantModel>>(
      stream: participantProvider.streamEventParticipants(widget.event.eventId),
      builder: (context, snapshot) {
        final participants = snapshot.data ?? [];
        final participantCount = participants.length;

        final isFull = widget.event.participantType == 'fixed' &&
            participantCount >= widget.event.maxParticipants;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isFull
                      ? AppColors.error(context).withValues(alpha: 0.08)
                      : AppColors.primary(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 18,
                          color: isFull
                              ? AppColors.error(context)
                              : AppColors.primary(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Participants',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '$participantCount',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isFull
                                ? AppColors.error(context)
                                : AppColors.primary(context),
                          ),
                        ),
                        if (widget.event.participantType == 'fixed') ...[
                          const SizedBox(width: 4),
                          Text(
                            '/ ${widget.event.maxParticipants}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
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
                stream: participantProvider.streamEventParticipantCount(widget.event.eventId),
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
              stream: participantProvider.streamEventParticipantCount(widget.event.eventId),
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

  Widget _buildSummaryMetric(BuildContext context, {required String label, required double value, required IconData icon, bool useWhite = false}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: useWhite ? Colors.white.withValues(alpha: 0.2) : AppColors.primary(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: useWhite ? Colors.white : AppColors.primary(context)),
          ),
          const SizedBox(height: 12),
          Text(
            '₹${value.toStringAsFixed(0)}', 
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w800, 
              color: useWhite ? Colors.white : AppColors.textPrimary(context)
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: useWhite ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary(context)
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


  Widget _buildFinancialSummaryCard(BuildContext context, ContributionProvider contributionProvider, ExpenseProvider expenseProvider, ParticipantProvider participantProvider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<double>(
      stream: contributionProvider.streamTotalContributions(widget.event.eventId),
      builder: (context, contributionSnapshot) {
        final totalCollected = contributionSnapshot.data ?? 0.0;
        return StreamBuilder<double>(
          stream: expenseProvider.streamEventTotalExpenses(widget.event.eventId),
          builder: (context, expenseSnapshot) {
            final totalExpenses = expenseSnapshot.data ?? 0.0;
            final balanceAamount = totalCollected - totalExpenses;
            return StreamBuilder<int>(
              stream: participantProvider.streamEventParticipantCount(widget.event.eventId),
              builder: (context, participantSnapshot) {
                final participantCount = participantSnapshot.data ?? 0;
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
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.white), 
                            const SizedBox(width: 10), 
                            const Text(
                              'Financial Summary', 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryMetric(context, label: 'Collected', value: totalCollected, icon: Icons.payments_rounded, useWhite: true),
                            _buildSummaryMetric(context, label: 'Expenses', value: totalExpenses, icon: Icons.receipt_long_rounded, useWhite: true),
                            _buildSummaryMetric(context, label: 'Balance', value: balanceAamount, icon: Icons.account_balance_rounded, useWhite: true),
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

  Widget _buildExportButton(
    BuildContext context,
    ContributionProvider contributionProvider,
    ExpenseProvider expenseProvider,
    ParticipantProvider participantProvider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
          : const Icon(Icons.share_rounded, size: 20),
        label: Text(
          _isExporting ? 'Generating Report...' : 'Export Event Summary',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}






