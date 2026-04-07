import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../auth/models/user_model.dart';
import 'package:kofund/core/services/user_service.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../../core/constants/app_colors.dart';

class ProgramOverviewTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramOverviewTab({super.key, required this.program});

  @override
  State<ProgramOverviewTab> createState() => _ProgramOverviewTabState();
}

class _ProgramOverviewTabState extends State<ProgramOverviewTab> {
  void _onRefresh() {
    setState(() {});
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
    final userService = Provider.of<UserService>(context, listen: false);

    return Container(
      color: AppColors.background(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              _onRefresh();
              await Future.delayed(const Duration(milliseconds: 500));
            },
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProgramHeader(context, participantProvider),
                const SizedBox(height: 12),
                _buildFinancialSummaryCard(
                  context,
                  contributionProvider,
                  expenseProvider,
                  participantProvider,
                ),
                const SizedBox(height: 12),
                _buildProgramInfoCard(context, participantProvider, userService),
                const SizedBox(height: 12),
                _buildProgramStatusCard(context, participantProvider),
                const SizedBox(height: 88), // Extra space for FABs in parent
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramHeader(
    BuildContext context,
    ParticipantProvider participantProvider,
  ) {
    return StreamBuilder<List<ParticipantModel>>(
      stream: participantProvider.streamProgramParticipants(widget.program.programId),
      builder: (context, snapshot) {
        final participants = snapshot.data ?? [];
        final participantCount = participants.length;

        final isFull = widget.program.participantType == 'fixed' &&
            participantCount >= widget.program.maxParticipants;

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
                widget.program.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
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
                        if (widget.program.participantType == 'fixed') ...[
                          const SizedBox(width: 4),
                          Text(
                            '/ ${widget.program.maxParticipants}',
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
              const SizedBox(height: 20),
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
                  if (!widget.program.isMonthlyPaymentProgram && widget.program.programDate != null)
                    _buildHeaderInfoTile(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: 'Date',
                      value: DateFormat('MMM dd, yyyy').format(widget.program.programDate!),
                      valueColor: AppColors.primary(context),
                    ),
                  _buildHeaderInfoTile(
                    context,
                    icon: Icons.monetization_on_rounded,
                    title: 'Contribution',
                    value: widget.program.suggestedContribution != null
                        ? '₹${widget.program.suggestedContribution!.toStringAsFixed(0)}'
                        : 'Flexible',
                    valueColor: widget.program.suggestedContribution != null
                        ? AppColors.primary(context)
                        : AppColors.textSecondary(context),
                  ),
                  _buildHeaderInfoTile(
                    context,
                    icon: Icons.flag_rounded,
                    title: 'Status',
                    value: widget.program.isActive
                        ? 'Active'
                        : widget.program.isCompleted
                            ? 'Completed'
                            : 'Inactive',
                    valueColor: widget.program.isActive
                        ? AppColors.primary(context)
                        : widget.program.isCompleted
                            ? AppColors.textTertiary(context)
                            : AppColors.error(context),
                  ),
                  _buildHeaderInfoTile(
                    context,
                    icon: Icons.assessment_rounded,
                    title: 'Estimated Total',
                    value: _calculateEstimatedTotal(widget.program, participantCount),
                    valueColor: AppColors.primary(context),
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

  Widget _buildProgramInfoCard(
    BuildContext context,
    ParticipantProvider participantProvider,
    UserService userService,
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
                  'Program Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.program.programDate != null && !widget.program.isMonthlyPaymentProgram)
              _buildDetailTile(
                context,
                icon: Icons.calendar_today_rounded,
                label: 'Program Date',
                value: DateFormat('EEEE, MMMM dd, yyyy').format(widget.program.programDate!),
              ),
            const SizedBox(height: 12),
            if (widget.program.suggestedContribution != null)
              _buildDetailTile(
                context,
                icon: Icons.monetization_on_rounded,
                label: 'Suggested Contribution',
                value: '₹ ${widget.program.suggestedContribution!.toStringAsFixed(0)} per person',
                valueColor: Colors.green,
              ),
            const SizedBox(height: 12),
            if (widget.program.totalProgramAmount != null)
              _buildDetailTile(
                context,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Total Program Budget',
                value: '₹ ${widget.program.totalProgramAmount!.toStringAsFixed(0)}',
                valueColor: AppColors.primary(context),
              ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: participantProvider.streamProgramParticipantCount(widget.program.programId),
              builder: (context, snapshot) {
                final participantCount = snapshot.data ?? 0;
                return _buildDetailTile(
                  context,
                  icon: Icons.assessment_rounded,
                  label: 'Estimated Total Collection',
                  value: _calculateEstimatedTotal(widget.program, participantCount),
                  valueColor: AppColors.primary(context),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: participantProvider.streamProgramParticipantCount(widget.program.programId),
              builder: (context, snapshot) {
                final participantCount = snapshot.data ?? 0;
                return _buildDetailTile(
                  context,
                  icon: Icons.people_alt_rounded,
                  label: 'Participant Capacity',
                  value: widget.program.participantType == 'fixed'
                      ? '$participantCount / ${widget.program.maxParticipants} participants'
                      : 'Unlimited (Currently $participantCount joined)',
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<UserModel?>(
              future: userService.getUserById(widget.program.createdBy),
              builder: (context, snapshot) {
                String displayValue = widget.program.createdBy;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  displayValue = 'Loading...';
                } else if (snapshot.hasData && snapshot.data != null) {
                  final user = snapshot.data!;
                  displayValue = user.displayName ?? user.email ?? widget.program.createdBy;
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
              label: 'Participant Type',
              value: widget.program.participantType == 'fixed' ? 'Fixed (Limited slots)' : 'Unlimited (Open for all)',
              valueColor: widget.program.participantType == 'fixed' ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.program.status, context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _getStatusColor(widget.program.status, context).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(widget.program.status), size: 18, color: _getStatusColor(widget.program.status, context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Program Status', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        const SizedBox(height: 2),
                        Text(widget.program.status.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _getStatusColor(widget.program.status, context))),
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

  Widget _buildFinancialSummaryCard(BuildContext context, ContributionProvider contributionProvider, ExpenseProvider expenseProvider, ParticipantProvider participantProvider) {
    return StreamBuilder<double>(
      stream: contributionProvider.streamProgramTotalContributions(widget.program.programId),
      builder: (context, contributionSnapshot) {
        final totalCollected = contributionSnapshot.data ?? 0.0;
        return StreamBuilder<double>(
          stream: expenseProvider.streamProgramTotalExpenses(widget.program.programId),
          builder: (context, expenseSnapshot) {
            final totalExpenses = expenseSnapshot.data ?? 0.0;
            final balanceAmount = totalCollected - totalExpenses;
            return StreamBuilder<int>(
              stream: participantProvider.streamProgramParticipantCount(widget.program.programId),
              builder: (context, participantSnapshot) {
                final participantCount = participantSnapshot.data ?? 0;
                final double totalExpected = (widget.program.totalProgramAmount ?? 0.0) > 0 ? widget.program.totalProgramAmount! : (widget.program.suggestedContribution ?? 0.0) * (participantCount > 0 ? participantCount : (widget.program.isFixedParticipants ? widget.program.maxParticipants : 1));
                final progressPercentage = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0.0;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient(context), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.white), const SizedBox(width: 6), Text('Financial Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))]),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryMetric(context, label: 'Collected', value: totalCollected, icon: Icons.payments_rounded, accent: Colors.white),
                          _buildSummaryMetric(context, label: 'Expenses', value: totalExpenses, icon: Icons.receipt_long_rounded, accent: Colors.white),
                          _buildSummaryMetric(context, label: 'Balance', value: balanceAmount, icon: Icons.account_balance_rounded, accent: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (totalExpected > 0) ...[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Collection Target', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))), Text('₹${totalCollected.toStringAsFixed(0)} / ₹${totalExpected.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))]),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (totalCollected / totalExpected).clamp(0, 1), backgroundColor: Colors.white.withValues(alpha: 0.2), valueColor: AlwaysStoppedAnimation(Colors.white))),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryMetric(BuildContext context, {required String label, required double value, required IconData icon, required Color accent}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: accent.withValues(alpha: 0.8)),
        const SizedBox(height: 4),
        Text('₹${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
        Text(label, style: TextStyle(fontSize: 11, color: accent.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _buildProgramStatusCard(BuildContext context, ParticipantProvider participantProvider) {
    return Container(); // Placeholder for other status elements if needed
  }

  String _calculateEstimatedTotal(ProgramModel program, int participantCount) {
    double total = (program.totalProgramAmount ?? 0.0) > 0 ? program.totalProgramAmount! : (program.suggestedContribution ?? 0.0) * (participantCount > 0 ? participantCount : (program.isFixedParticipants ? program.maxParticipants : 1));
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
}
