import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../expenses/models/expense_model.dart';
import '../../../auth/models/user_model.dart';
import 'package:kofund/core/services/user_service.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../programs/providers/program_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../../core/constants/app_colors.dart';

class ProgramOverviewTab extends StatelessWidget {
  final ProgramModel program;

  const ProgramOverviewTab({super.key, required this.program});
  @override
  Widget build(BuildContext context) {
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final participantProvider = Provider.of<ParticipantProvider>(context);
    final programProvider = Provider.of<ProgramProvider>(context);
    final userService = Provider.of<UserService>(context, listen: false);

return SingleChildScrollView(
  padding: const EdgeInsets.all(12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔹 Centered Program Header
     _buildProgramHeader(context, participantProvider),


      const SizedBox(height: 12),

      // 🔹 Financial Summary FIRST (High priority)
      _buildFinancialSummaryCard(
        context,
        contributionProvider,
        expenseProvider,
        participantProvider,
      ),

      const SizedBox(height: 12),

      // 🔹 Program Information (Secondary)
      _buildProgramInfoCard(context, participantProvider, userService),

      const SizedBox(height: 12),

      // 🔹 Program Status
      _buildProgramStatusCard(context, participantProvider),

      const SizedBox(height: 12),


    ],
  ),
);

  }



Widget _buildProgramHeader(
  BuildContext context,
  ParticipantProvider participantProvider,
) {
  return StreamBuilder<List<ParticipantModel>>(
    stream: participantProvider.streamProgramParticipants(program.programId),
    builder: (context, snapshot) {
      final participants = snapshot.data ?? [];
      final participantCount = participants.length;

      final isFull = program.participantType == 'fixed' &&
          participantCount >= program.maxParticipants;

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
            /// 🔹 PROGRAM TITLE
            Text(
              program.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),

            /// 🔹 PARTICIPANTS STATUS (HIGHLIGHTED)
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
                      if (program.participantType == 'fixed') ...[
                        const SizedBox(width: 4),
                        Text(
                          '/ ${program.maxParticipants}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
              ),
                ]
            ),
          ),

          const SizedBox(height: 20),

          /// 🔹 QUICK INFO GRID
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
              // 📅 DATE
           // Only show date for non-monthly programs with a valid date
if (!program.isMonthlyPaymentProgram && program.programDate != null)
  _buildHeaderInfoTile(
    context,
    icon: Icons.calendar_today_rounded,
    title: 'Date',
    value: DateFormat('MMM dd, yyyy').format(program.programDate!),
    valueColor: AppColors.primary(context),
  ),

   _buildHeaderInfoTile(
                context,
                icon: Icons.monetization_on_rounded,
                title: 'Contribution',
                value: program.suggestedContribution != null
                    ? '₹${program.suggestedContribution!.toStringAsFixed(0)}'
                    : 'Flexible',
                valueColor: program.suggestedContribution != null
                    ? AppColors.primary(context)
                    : AppColors.textSecondary(context),
              ),
                    _buildHeaderInfoTile(
                context,
                icon: Icons.flag_rounded,
                title: 'Status',
                value: program.isActive
                    ? 'Active'
                    : program.isCompleted
                        ? 'Completed'
                        : 'Inactive',
                valueColor: program.isActive
                    ? AppColors.primary(context)
                    : program.isCompleted
                        ? AppColors.textTertiary(context)
                        : AppColors.error(context),
              ),
// In _buildProgramHeader, replace the existing Estimated Total tile with:
_buildHeaderInfoTile(
  context,
  icon: Icons.assessment_rounded,
  title: 'Estimated Total',
  value: _calculateEstimatedTotal(program, participantCount),
  valueColor: AppColors.primary(context),
),
              // 💰 CONTRIBUTION
           

              // 🎯 STATUS
        
            ],
          ),
        ],
      ),
    );
  },
);
}

// Helper for header info tiles
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
        Icon(
          icon,
          size: 16,
          color: AppColors.primary(context),
        ),
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



  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // Reduced from 12
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16, // Reduced from 18
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

Widget _buildProgramInfoCard(
  BuildContext context,
  ParticipantProvider participantProvider,
  UserService _userService,
) {
  return Card(
    color: AppColors.card(context),
    elevation: 0.8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: AppColors.border(context),
        width: 0.6,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 HEADER
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppColors.primary(context),
              ),
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

        // 📅 FULL DATE WITH DAY
if (program.programDate != null && !program.isMonthlyPaymentProgram)
  _buildDetailTile(
    context,
    icon: Icons.calendar_today_rounded,
    label: 'Program Date',
    value: DateFormat('EEEE, MMMM dd, yyyy').format(program.programDate!),
  ),

          const SizedBox(height: 12),

        

          // 💰 SUGGESTED CONTRIBUTION DETAILS
          if (program.suggestedContribution != null)
            Column(
              children: [
                _buildDetailTile(
                  context,
                  icon: Icons.monetization_on_rounded,
                  label: 'Suggested Contribution',
                  value: '₹ ${program.suggestedContribution!.toStringAsFixed(0)} per person',
                  valueColor: AppColors.success(context),
                ),
                const SizedBox(height: 12),
              ],
            ),

          // 💼 TOTAL BUDGET
          if (program.totalProgramAmount != null)
            Column(
              children: [
                _buildDetailTile(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Total Program Budget',
                  value: '₹ ${program.totalProgramAmount!.toStringAsFixed(0)}',
                  valueColor: AppColors.primary(context),
                ),
                const SizedBox(height: 12),
              ],
            ),

       // 📊 ESTIMATED TOTAL - Replace the existing section
StreamBuilder<int>(
  stream: participantProvider.streamProgramParticipantCount(program.programId),
  builder: (context, snapshot) {
    final participantCount = snapshot.data ?? 0;
    
    return Column(
      children: [
        _buildDetailTile(
          context,
          icon: Icons.assessment_rounded,
          label: 'Estimated Total Collection',
          value: _calculateEstimatedTotal(program, participantCount),
          valueColor: AppColors.primary(context),
        ),
        const SizedBox(height: 12),
      ],
    );
  },
),

          // 👥 PARTICIPANT DETAILS
          StreamBuilder<int>(
            stream: participantProvider
                .streamProgramParticipantCount(program.programId),
            builder: (context, snapshot) {
              final participantCount = snapshot.data ?? 0;

              return Column(
                children: [
                  _buildDetailTile(
                    context,
                    icon: Icons.people_alt_rounded,
                    label: 'Participant Capacity',
                    value: program.participantType == 'fixed'
                        ? '$participantCount / ${program.maxParticipants} participants'
                        : 'Unlimited (Currently $participantCount joined)',
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),

      // 👤 CREATED BY
// 👤 CREATED BY
FutureBuilder<UserModel?>(
  future: _userService.getUserById(program.createdBy),
  builder: (context, snapshot) {
    String displayValue = program.createdBy; // Default fallback to UID
    
    if (snapshot.connectionState == ConnectionState.waiting) {
      displayValue = 'Loading...';
    } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
      displayValue = program.createdBy; // Fallback to UID on error
    } else {
      final user = snapshot.data!;
      displayValue = user.displayName ?? 
                     user.email ?? 
                     user.phoneNumber ?? 
                     program.createdBy;
    }
    
    return Column(
      children: [
        _buildDetailTile(
          context,
          icon: Icons.person_outline_rounded,
          label: 'Organized By',
          value: displayValue,
        ),
        const SizedBox(height: 12),
      ],
    );
  },
),
          const SizedBox(height: 12),

          // 🏷️ PARTICIPANT TYPE
          _buildDetailTile(
            context,
            icon: Icons.groups_rounded,
            label: 'Participant Type',
            value: program.participantType == 'fixed'
                ? 'Fixed (Limited slots)'
                : 'Unlimited (Open for all)',
            valueColor: program.participantType == 'fixed'
                ? AppColors.warning(context)
                : AppColors.success(context),
          ),

          const SizedBox(height: 12),

          // 🚩 PROGRAM STATUS
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(program.status, context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getStatusColor(program.status, context).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(program.status),
                  size: 18,
                  color: _getStatusColor(program.status, context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Program Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        program.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _getStatusColor(program.status, context),
                        ),
                      ),
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

// Helper for detail tiles
Widget _buildDetailTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  Color? valueColor,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Icon
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary(context).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: AppColors.primary(context),
        ),
      ),

      const SizedBox(width: 12),

      // Text content
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

String _calculateEstimatedTotal(ProgramModel program, int participantCount) {
  double total = 0.0;
  
  // 1. Use totalProgramAmount if it exists and is positive
  if (program.totalProgramAmount != null && program.totalProgramAmount! > 0) {
    total = program.totalProgramAmount!;
  }
  // 2. Fallback to suggestedContribution * participantCount
  else if (program.suggestedContribution != null && program.suggestedContribution! > 0) {
    final count = participantCount > 0 ? participantCount : 
                 (program.isFixedParticipants ? program.maxParticipants : 1);
    total = program.suggestedContribution! * count;
  }
  
  return '₹${total.toStringAsFixed(0)}';
}

// Helper to get status icon
IconData _getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return Icons.play_arrow_rounded;
    case 'completed':
      return Icons.check_circle_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    case 'upcoming':
      return Icons.schedule_rounded;
    default:
      return Icons.info_rounded;
  }
}
Widget _buildModernInfoTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  Color? valueColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.primary(context).withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary(context).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.primary(context),
          ),
        ),

        const SizedBox(width: 10),

        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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


Widget _buildFinancialSummaryCard(
  BuildContext context,
  ContributionProvider contributionProvider,
  ExpenseProvider expenseProvider,
  ParticipantProvider participantProvider,
) {
  return Column(
    children: [
      StreamBuilder<double>(
        stream: contributionProvider
            .streamProgramTotalContributions(program.programId),
        builder: (context, contributionSnapshot) {
          final totalCollected = contributionSnapshot.data ?? 0.0;

          return StreamBuilder<double>(
            stream: expenseProvider
                .streamProgramTotalExpenses(program.programId),
            builder: (context, expenseSnapshot) {
              final totalExpenses = expenseSnapshot.data ?? 0.0;
              final balanceAmount = totalCollected - totalExpenses;

              // ✅ Get participant count
              return StreamBuilder<int>(
                stream: participantProvider
                    .streamProgramParticipantCount(program.programId),
                builder: (context, participantSnapshot) {
                  final participantCount = participantSnapshot.data ?? 0;
                  
                  // ✅ Calculate totalExpected with proper fallback
                  final double totalExpected;
                  
                  if (program.totalProgramAmount != null && program.totalProgramAmount! > 0) {
                    totalExpected = program.totalProgramAmount!;
                  } else if (program.suggestedContribution != null && program.suggestedContribution! > 0) {
                    // Use actual participant count for calculation
                    final count = participantCount > 0 ? participantCount : 
                                 (program.isFixedParticipants ? program.maxParticipants : 1);
                    totalExpected = program.suggestedContribution! * count;
                  } else {
                    totalExpected = 0.0;
                  }

                  final progressPercentage = totalExpected > 0 
                      ? (totalCollected / totalExpected) * 100 
                      : 0.0;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 Header
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 18,
                              color: AppColors.textCards(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Financial Summary',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textCards(context),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // 🔹 Top Stats (Collected / Expenses / Balance)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryMetric(
                              context,
                              label: 'Collected',
                              value: totalCollected,
                              icon: Icons.payments_rounded,
                              accent: AppColors.textCards(context),
                            ),
                            _buildSummaryMetric(
                              context,
                              label: 'Expenses',
                              value: totalExpenses,
                              icon: Icons.receipt_long_rounded,
                              accent: AppColors.textCards(context),
                            ),
                            _buildSummaryMetric(
                              context,
                              label: 'Balance',
                              value: balanceAmount,
                              icon: Icons.account_balance_rounded,
                              accent: balanceAmount >= 0
                                  ? AppColors.textCards(context)
                                  : AppColors.warning(context),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 🔹 Progress Section
                        Text(
                          'Collection Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textCards(context).withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${totalCollected.toStringAsFixed(0)} / ₹${totalExpected.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textCards(context),
                              ),
                            ),
                            Text(
                              '${progressPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textCards(context),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: totalExpected > 0
                                ? totalCollected / totalExpected
                                : 0,
                            minHeight: 6,
                            backgroundColor: AppColors.textCards(context)
                                .withValues(alpha: 0.25),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textCards(context),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // 🔹 Target / Estimate Info - USING ACTUAL PARTICIPANT COUNT
                        if (program.totalProgramAmount != null && program.totalProgramAmount! > 0)
                          Text(
                            'Target Budget: ₹${program.totalProgramAmount!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textCards(context)
                                  .withValues(alpha: 0.75),
                            ),
                          )
                        else if (program.suggestedContribution != null && program.suggestedContribution! > 0)
                          Text(
                            'Estimated: ₹${program.suggestedContribution!.toStringAsFixed(0)} × ${participantCount.toString()} participants',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textCards(context)
                                  .withValues(alpha: 0.75),
                            ),
                          ),

                        const SizedBox(height: 10),

                        // 🔹 Financial Warning
                        if (balanceAmount < 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning(context)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: AppColors.warning(context),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Expenses exceed contributions by ₹${balanceAmount.abs().toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.warning(context),
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
              );
            },
          );
        },
      ),

      const SizedBox(height: 10),

      // 🔹 Detailed Breakdown
      _buildDetailedFinancialBreakdown(
        context,
        contributionProvider,
        expenseProvider,
      ),
    ],
  );
}
Widget _buildSummaryMetric(
  BuildContext context, {
  required String label,
  required double value,
  required IconData icon,
  required Color accent,
}) {
  return Column(
    children: [
      Icon(icon, size: 18, color: accent),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textCards(context).withValues(alpha: 0.8),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        '₹${value.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textCards(context),
        ),
      ),
    ],
  );
}


 Widget _buildDetailedFinancialBreakdown(
  BuildContext context,
  ContributionProvider contributionProvider,
  ExpenseProvider expenseProvider,
) {
  return Card(
    color: AppColors.card(context),
    elevation: 0.8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: AppColors.border(context),
        width: 0.6,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Header
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: AppColors.primary(context),
              ),
              const SizedBox(width: 6),
              Text(
                'Financial Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 🔹 Contribution Stats
          StreamBuilder<List<ContributionModel>>(
            stream: contributionProvider
                .streamProgramContributions(program.programId),
            builder: (context, snapshot) {
              final contributions = snapshot.data ?? [];
              final completed = contributions
                  .where((c) => c.status == 'completed')
                  .length;
              final pending = contributions
                  .where((c) => c.status == 'pending')
                  .length;

              return _buildModernStatTile(
                context: context,
                title: 'Contributions',
                icon: Icons.payments_rounded,
                accentColor: AppColors.success(context),
                total: contributions.length,
                approvedLabel: 'Completed',
                approvedCount: completed,
                pendingCount: pending,
              );
            },
          ),

          const SizedBox(height: 10),

          // 🔹 Expense Stats
          StreamBuilder<List<ExpenseModel>>(
            stream:
                expenseProvider.streamProgramExpenses(program.programId),
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? [];
              final approved =
                  expenses.where((e) => e.status == 'approved').length;
              final pending =
                  expenses.where((e) => e.status == 'pending').length;

              return _buildModernStatTile(
                context: context,
                title: 'Expenses',
                icon: Icons.receipt_long_rounded,
                accentColor: AppColors.error(context),
                total: expenses.length,
                approvedLabel: 'Approved',
                approvedCount: approved,
                pendingCount: pending,
              );
            },
          ),
        ],
      ),
    ),
  );
}
Widget _buildModernStatTile({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Color accentColor,
  required int total,
  required String approvedLabel,
  required int approvedCount,
  required int pendingCount,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: accentColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        // Icon Badge
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: accentColor,
          ),
        ),

        const SizedBox(width: 12),

        // Stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$total total • $approvedLabel: $approvedCount • Pending: $pendingCount',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildFinancialItem(BuildContext context, String title, double amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11, // Reduced from 12
            color: AppColors.textCards(context).withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2), // Reduced from 4
        Text(
          '₹${amount.toStringAsFixed(0)}', // Removed space
          style: TextStyle(
            fontSize: 14, // Reduced from 16
            fontWeight: FontWeight.bold,
            color: AppColors.textCards(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialRow(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32, // Reduced from 36
          height: 32, // Reduced from 36
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18), // Reduced from 20
        ),
        const SizedBox(width: 10), // Reduced from 12
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13, // Reduced from 14
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11, // Reduced from 12
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildProgramStatusCard(
  BuildContext context,
  ParticipantProvider participantProvider,
) {
  return StreamBuilder<int>(
    stream: participantProvider
        .streamProgramParticipantCount(program.programId),
    builder: (context, snapshot) {
      final participantCount = snapshot.data ?? 0;

      final isFull = program.participantType == 'fixed' &&
          participantCount >= program.maxParticipants;

      final canJoin =
          program.participantType == 'unlimited' || !isFull;

      final availableSpots = program.participantType == 'unlimited'
          ? null
          : program.maxParticipants - participantCount;

      final statusColor =
          _getStatusColor(program.status, context);

      return Card(
        color: AppColors.card(context),
        elevation: 0.8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.border(context),
            width: 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Header with Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timeline_rounded,
                        size: 18,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Program Status',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(
                    program.status.toUpperCase(),
                    statusColor,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 🔹 Status Grid
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                ),
                children: [
                  _buildStatusTile(
                    context,
                    icon: Icons.people_alt_rounded,
                    label: 'Participants',
                    value: participantCount.toString(),
                    color: AppColors.primary(context),
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.event_seat_rounded,
                    label: 'Available Spots',
                    value: program.participantType ==
                            'unlimited'
                        ? 'Unlimited'
                        : availableSpots.toString(),
                    color: canJoin
                        ? AppColors.success(context)
                        : AppColors.error(context),
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.groups_rounded,
                    label: 'Participant Type',
                    value: program.participantType ==
                            'fixed'
                        ? 'Fixed'
                        : 'Unlimited',
                    color: AppColors.primary(context),
                  ),
                  _buildStatusTile(
                    context,
                    icon: Icons.flag_rounded,
                    label: 'Timeline',
                    value: program.isOngoing
                        ? 'Ongoing'
                        : program.isCompleted
                            ? 'Completed'
                            : 'Active',
                    color: program.isOngoing
                        ? AppColors.warning(context)
                        : program.isCompleted
                            ? AppColors.textTertiary(
                                context)
                            : AppColors.success(context),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 🔹 Capacity Indicator
              _buildCapacityIndicator(
                context,
                isFull: isFull,
                participantCount: participantCount,
              ),
            ],
          ),
        ),
      );
    },
  );
}
Widget _buildStatusBadge(String text, Color color) {
  return Container(
    padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.4,
      ),
    ),
  );
}
Widget _buildStatusTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
Widget _buildCapacityIndicator(
  BuildContext context, {
  required bool isFull,
  required int participantCount,
}) {
  final color =
      isFull ? AppColors.error(context) : AppColors.success(context);

  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          isFull ? Icons.block_rounded : Icons.check_circle_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          isFull
              ? 'Program capacity is full'
              : 'Program has available slots',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}



  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary(context), size: 20), // Reduced from 22
        const SizedBox(width: 10), // Reduced from 12
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13, // Reduced from 14
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2), // Reduced from 4
              Text(
                value,
                style: TextStyle(
                  fontSize: 14, // Reduced from 16
                  color: AppColors.textPrimary(context),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(BuildContext context, String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13, // Reduced from 14
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), // Reduced from 12,4
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10), // Reduced from 12
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11, // Reduced from 12
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success(context);
      case 'completed':
        return AppColors.textTertiary(context);
      case 'cancelled':
        return AppColors.error(context);
      default:
        return AppColors.textTertiary(context);
    }
  }

  Color _getProgressColor(double percentage, BuildContext context) {
    if (percentage >= 75) return AppColors.success(context);
    if (percentage >= 50) return AppColors.primary(context);
    if (percentage >= 25) return AppColors.warning(context);
    return AppColors.error(context);
  }

  void _joinProgram(BuildContext context, ParticipantProvider participantProvider, AppAuthProvider authProvider) async {
    try {
      final currentUser = authProvider.user;
      if (currentUser == null) return;
      
      final participant = ParticipantModel(
        participantId: '',
        programId: program.programId,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'User',
        userEmail: currentUser.email ?? '',
        communityId: program.communityId,
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: program.suggestedContribution != null ? 0 : null,
        hasPaidContribution: program.suggestedContribution == null,
      );

      await participantProvider.joinProgram(participant);
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined the program!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join program: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

  void _leaveProgram(BuildContext context, ParticipantProvider participantProvider, AppAuthProvider authProvider) async {
    try {
      final currentUser = authProvider.user;
      if (currentUser == null) return;
      
      await participantProvider.leaveProgram(program.programId, currentUser.uid);
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Left the program successfully!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave program: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

  void _shareProgram() {
    // Implement share functionality
    debugPrint('Share program: ${program.title}');
  }
}

