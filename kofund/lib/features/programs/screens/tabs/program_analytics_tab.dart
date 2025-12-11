import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/program_provider.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../models/program_model.dart';

class ProgramAnalyticsTab extends StatelessWidget {
  final ProgramModel program;

  const ProgramAnalyticsTab({super.key, required this.program});

  @override
  Widget build(BuildContext context) {
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Collection Progress (Real-time)
          StreamBuilder<Map<String, dynamic>>(
            stream: _getFinancialProgressStream(context, programProvider, contributionProvider, program.programId),
            builder: (context, snapshot) {
              final progressData = snapshot.data ?? {
                'totalCollected': 0.0,
                'progressPercentage': 0.0,
                'estimatedTotal': 0.0,
                'hasFinancialGoals': false,
                'participantCount': 0,
              };

              final totalCollected = progressData['totalCollected'] as double;
              final progressPercentage = progressData['progressPercentage'] as double;
              final estimatedTotal = progressData['estimatedTotal'] as double;
              final hasFinancialGoals = progressData['hasFinancialGoals'] as bool;
              final participantCount = progressData['participantCount'] as int;

              return _buildAnalyticsCard(
                'Collection Progress',
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹ ${totalCollected.toStringAsFixed(0)} / ₹ ${estimatedTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${progressPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getProgressColor(progressPercentage),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: estimatedTotal > 0 ? totalCollected / estimatedTotal : 0,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progressPercentage)),
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    if (!hasFinancialGoals) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No financial goals set for this program',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Participant Engagement (Real-time)
          StreamBuilder<int>(
            stream: programProvider.streamProgramParticipantCount(program.programId),
            builder: (context, participantSnapshot) {
              final participantCount = participantSnapshot.data ?? 0;
              
              return StreamBuilder<List<ContributionModel>>(
                stream: contributionProvider.streamProgramContributions(program.programId),
                builder: (context, contributionSnapshot) {
                  final contributions = contributionSnapshot.data ?? [];
                  final paidParticipants = contributions
                      .where((c) => c.status == 'completed')
                      .map((c) => c.userId)
                      .toSet()
                      .length;

                  return _buildAnalyticsCard(
                    'Participant Engagement',
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricItem('Joined', participantCount.toString(), Icons.people),
                        _buildMetricItem('Active', participantCount.toString(), Icons.person),
                        _buildMetricItem('Paid', paidParticipants.toString(), Icons.payments),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),

          // Financial Health (Real-time)
          StreamBuilder<double>(
            stream: contributionProvider.streamProgramTotalContributions(program.programId),
            builder: (context, contributionSnapshot) {
              final totalContributions = contributionSnapshot.data ?? 0.0;
              
              return StreamBuilder<double>(
                stream: expenseProvider.streamProgramTotalExpenses(program.programId),
                builder: (context, expenseSnapshot) {
                  final totalExpenses = expenseSnapshot.data ?? 0.0;
                  final netBalance = totalContributions - totalExpenses;
                  final isHealthy = netBalance >= 0;

                  return _buildAnalyticsCard(
                    'Financial Health',
                    Column(
                      children: [
                        _buildFinancialRow('Total Contributions', '₹ ${totalContributions.toStringAsFixed(0)}', Colors.green),
                        _buildFinancialRow('Total Expenses', '₹ ${totalExpenses.toStringAsFixed(0)}', Colors.red),
                        _buildFinancialRow('Net Balance', '₹ ${netBalance.toStringAsFixed(0)}', 
                            isHealthy ? Colors.green : Colors.orange),
                        if (netBalance < 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange.shade600, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Expenses exceed contributions by ₹ ${netBalance.abs().toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),

          // Quick Stats (Real-time)
          StreamBuilder<Map<String, dynamic>>(
            stream: _getQuickStatsStream(programProvider, contributionProvider, expenseProvider, program.programId),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {
                'avgContribution': 0.0,
                'completionRate': 0.0,
                'daysRemaining': 0,
                'expenseRatio': 0.0,
              };

              return _buildAnalyticsCard(
                'Quick Stats',
                Column(
                  children: [
                    _buildStatRow('Avg. Contribution', '₹ ${stats['avgContribution'].toStringAsFixed(0)}'),
                    _buildStatRow('Completion Rate', '${stats['completionRate'].toStringAsFixed(1)}%'),
                    _buildStatRow('Days Remaining', '${stats['daysRemaining']} days'),
                    _buildStatRow('Expense Ratio', '${stats['expenseRatio'].toStringAsFixed(1)}%'),
                  ],
                ),
              );
            },
          ),

          // Program Financial Goals
          if (program.hasFinancialGoals) ...[
            const SizedBox(height: 16),
            _buildAnalyticsCard(
              'Financial Goals',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (program.suggestedContribution != null && program.suggestedContribution! > 0)
                    _buildGoalRow('Suggested Contribution', '₹ ${program.suggestedContribution!.toStringAsFixed(0)} per person'),
                  if (program.totalProgramAmount != null)
                    _buildGoalRow('Total Program Budget', '₹ ${program.totalProgramAmount!.toStringAsFixed(0)}'),
                  if (program.hasFinancialGoals)
                    _buildGoalRow('Estimated Total', '₹ ${program.estimatedTotalAmount.toStringAsFixed(0)} (calculated)'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Stream<Map<String, dynamic>> _getFinancialProgressStream(
    BuildContext context,
    ProgramProvider programProvider,
    ContributionProvider contributionProvider,
    String programId,
  ) {
    return programProvider.streamProgramParticipantCount(programId).asyncMap((participantCount) async {
      final totalCollected = await contributionProvider.getProgramTotalContributions(programId);
      
      // Use the ProgramModel's built-in properties
      final estimatedTotal = program.estimatedTotalAmount;
      final hasFinancialGoals = program.hasFinancialGoals;
      final progressPercentage = program.calculateProgress(totalCollected);
      
      return {
        'totalCollected': totalCollected,
        'progressPercentage': progressPercentage,
        'estimatedTotal': estimatedTotal,
        'hasFinancialGoals': hasFinancialGoals,
        'participantCount': participantCount,
      };
    });
  }

  Stream<Map<String, dynamic>> _getQuickStatsStream(
    ProgramProvider programProvider,
    ContributionProvider contributionProvider,
    ExpenseProvider expenseProvider,
    String programId,
  ) {
    return programProvider.streamProgramParticipantCount(programId).asyncMap((participantCount) async {
      final contributions = await contributionProvider.getProgramContributions(programId);
      final completedContributions = contributions.where((c) => c.status == 'completed').toList();
      
      // Calculate average contribution
      final avgContribution = completedContributions.isNotEmpty 
          ? completedContributions.map((c) => c.amount).reduce((a, b) => a + b) / completedContributions.length
          : 0.0;

      // Calculate completion rate (paid participants vs total participants)
      final paidParticipants = completedContributions.map((c) => c.userId).toSet().length;
      final completionRate = participantCount > 0 
          ? (paidParticipants / participantCount) * 100
          : 0.0;

      // Calculate days remaining
      final daysRemaining = program.programDate.difference(DateTime.now()).inDays;
      
      // Calculate expense ratio (expenses vs contributions)
      final totalContributions = await contributionProvider.getProgramTotalContributions(programId);
      final totalExpenses = await expenseProvider.getProgramTotalExpenses(programId);
      final expenseRatio = totalContributions > 0 
          ? (totalExpenses / totalContributions) * 100
          : 0.0;

      return {
        'avgContribution': avgContribution,
        'completionRate': completionRate,
        'daysRemaining': daysRemaining > 0 ? daysRemaining : 0,
        'expenseRatio': expenseRatio,
      };
    });
  }

  Widget _buildAnalyticsCard(String title, Widget content) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 30),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFinancialRow(String title, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.blue.shade600;
    if (percentage >= 25) return Colors.orange;
    return Colors.red;
  }
}