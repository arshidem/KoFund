import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../expenses/models/expense_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../programs/providers/program_provider.dart';
import '../../../participants/models/participant_model.dart';

class ProgramOverviewTab extends StatelessWidget {
  final ProgramModel program;

  const ProgramOverviewTab({super.key, required this.program});

  @override
  Widget build(BuildContext context) {
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final participantProvider = Provider.of<ParticipantProvider>(context);
    final programProvider = Provider.of<ProgramProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program Header
          _buildProgramHeader(),
          const SizedBox(height: 20),

          // Program Information Card
          _buildSectionTitle('Program Information'),
          _buildProgramInfoCard(participantProvider),

          const SizedBox(height: 20),

          // Financial Summary Card (Real-time)
          _buildSectionTitle('Financial Summary'),
          _buildFinancialSummaryCard(context, contributionProvider, expenseProvider, participantProvider),

          const SizedBox(height: 20),

          // Program Status Card
          _buildSectionTitle('Program Status'),
          _buildProgramStatusCard(participantProvider),

          const SizedBox(height: 20),

          // Quick Actions
          _buildSectionTitle('Quick Actions'),
          _buildActionButtons(context, participantProvider),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProgramHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          program.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                program.programType.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(program.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getStatusColor(program.status).withOpacity(0.3)),
              ),
              child: Text(
                program.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(program.status),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildProgramInfoCard(ParticipantProvider participantProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.calendar_today,
              'Program Date',
              DateFormat('EEEE, MMMM dd, yyyy').format(program.programDate),
            ),
            
         

            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Location', program.location),

            // Suggested Contribution (handle null)
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.monetization_on,
              'Suggested Contribution',
              program.suggestedContribution != null 
                  ? '₹ ${program.suggestedContribution!.toStringAsFixed(2)}'
                  : 'Not set',
            ),

            // Total Program Amount (handle null)
            if (program.totalProgramAmount != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.account_balance_wallet,
                'Total Program Budget',
                '₹ ${program.totalProgramAmount!.toStringAsFixed(2)}',
              ),
            ],

            // Estimated Total Amount
            if (program.hasFinancialGoals) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.assessment,
                'Estimated Total',
                '₹ ${program.estimatedTotalAmount.toStringAsFixed(2)}',
              ),
            ],

            // Real-time participant count
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: participantProvider.streamProgramParticipantCount(program.programId),
              builder: (context, snapshot) {
                final participantCount = snapshot.data ?? 0;
                return _buildInfoRow(
                  Icons.people,
                  'Participants',
                  '$participantCount / ${program.participantType == 'fixed' ? program.maxParticipants : 'Unlimited'}',
                );
              },
            ),

            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Created By', program.createdBy),
          ],
        ),
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
        // Real-time financial progress
        StreamBuilder<double>(
          stream: contributionProvider.streamProgramTotalContributions(program.programId),
          builder: (context, contributionSnapshot) {
            final totalCollected = contributionSnapshot.data ?? 0.0;
            
            return StreamBuilder<double>(
              stream: expenseProvider.streamProgramTotalExpenses(program.programId),
              builder: (context, expenseSnapshot) {
                final totalExpenses = expenseSnapshot.data ?? 0.0;
                final balanceAmount = totalCollected - totalExpenses;
                
                // USE PROGRAM MODEL'S BUILT-IN METHODS
                final totalExpected = program.estimatedTotalAmount;
                final progressPercentage = program.calculateProgress(totalCollected);
                final hasFinancialGoals = program.hasFinancialGoals;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Financial Overview Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFinancialItem('Collected', totalCollected, Colors.green),
                            _buildFinancialItem('Expenses', totalExpenses, Colors.red),
                            _buildFinancialItem('Balance', balanceAmount, 
                                balanceAmount >= 0 ? Colors.blue : Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Collection Progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Collection Progress',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '₹ ${totalCollected.toStringAsFixed(2)} / ₹ ${totalExpected.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (program.totalProgramAmount != null)
                                  Text(
                                    'Target: ₹ ${program.totalProgramAmount!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                if (program.totalProgramAmount == null && program.suggestedContribution != null)
                                  Text(
                                    'Estimated: ₹ ${program.suggestedContribution!} × ${program.currentParticipants} participants',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              '${progressPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getProgressColor(progressPercentage),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: totalExpected > 0 ? totalCollected / totalExpected : 0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progressPercentage)),
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 8),
                        
                        // Financial Health Indicator
                        if (balanceAmount < 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange.shade600, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Expenses exceed contributions by ₹ ${balanceAmount.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        
        const SizedBox(height: 12),
        
        // Detailed Financial Breakdown
        _buildDetailedFinancialBreakdown(contributionProvider, expenseProvider),
      ],
    );
  }

  Widget _buildDetailedFinancialBreakdown(ContributionProvider contributionProvider, ExpenseProvider expenseProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Real-time Contribution Statistics
            StreamBuilder<List<ContributionModel>>(
              stream: contributionProvider.streamProgramContributions(program.programId),
              builder: (context, contributionListSnapshot) {
                final contributions = contributionListSnapshot.data ?? [];
                final completedContributions = contributions.where((c) => c.status == 'completed').length;
                final pendingContributions = contributions.where((c) => c.status == 'pending').length;
                
                return _buildFinancialRow(
                  'Contributions',
                  '${contributions.length} total ($completedContributions completed, $pendingContributions pending)',
                  Icons.payments,
                  Colors.green,
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Real-time Expense Statistics
            StreamBuilder<List<ExpenseModel>>(
              stream: expenseProvider.streamProgramExpenses(program.programId),
              builder: (context, expenseListSnapshot) {
                final expenses = expenseListSnapshot.data ?? [];
                final approvedExpenses = expenses.where((e) => e.status == 'approved').length;
                final pendingExpenses = expenses.where((e) => e.status == 'pending').length;
                
                return _buildFinancialRow(
                  'Expenses',
                  '${expenses.length} total ($approvedExpenses approved, $pendingExpenses pending)',
                  Icons.receipt,
                  Colors.red,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialItem(String title, double amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₹ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialRow(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgramStatusCard(ParticipantProvider participantProvider) {
    return StreamBuilder<int>(
      stream: participantProvider.streamProgramParticipantCount(program.programId),
      builder: (context, snapshot) {
        final participantCount = snapshot.data ?? 0;
        final isFull = program.participantType == 'fixed' && participantCount >= program.maxParticipants;
        final canJoin = program.participantType == 'unlimited' || !isFull;
        final availableSpots = program.participantType == 'unlimited' ? 999 : program.maxParticipants - participantCount;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatusRow('Program Status', program.status.toUpperCase(), 
                    _getStatusColor(program.status)),
                
                const SizedBox(height: 12),
                
                _buildStatusRow(
                  'Available Spots',
                  availableSpots == 999 ? 'Unlimited' : availableSpots.toString(),
                  canJoin ? Colors.green : Colors.red,
                ),
                
                const SizedBox(height: 12),
                
                _buildStatusRow(
                  'Current Participants',
                  participantCount.toString(),
                  Colors.blue,
                ),
                
                const SizedBox(height: 12),
                
                _buildStatusRow(
                  'Participant Type',
                  program.participantType == 'fixed' ? 'Fixed Limit' : 'Unlimited',
                  Colors.blue,
                ),
                
                const SizedBox(height: 12),
                
                // ✅ UPDATED: Remove isUpcoming reference
                _buildStatusRow(
                  'Timeline',
                  program.isOngoing ? 'Ongoing' : 
                  program.isCompleted ? 'Completed' : 'Active',
                  program.isOngoing ? Colors.orange : 
                  program.isCompleted ? Colors.grey : Colors.green,
                ),
                
                const SizedBox(height: 12),
                
                _buildStatusRow(
                  'Capacity',
                  isFull ? 'Full' : 'Available',
                  isFull ? Colors.red : Colors.green,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, ParticipantProvider participantProvider) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    
    return StreamBuilder<int>(
      stream: participantProvider.streamProgramParticipantCount(program.programId),
      builder: (context, snapshot) {
        final participantCount = snapshot.data ?? 0;
        final currentUserId = authProvider.user?.uid;
        final hasUserJoined = currentUserId != null && 
            participantProvider.programParticipants.any((p) => p.userId == currentUserId && p.status == 'joined');

        final isFull = program.participantType == 'fixed' && participantCount >= program.maxParticipants;
        final canJoin = program.participantType == 'unlimited' || !isFull;

        return Row(
          children: [
            // ✅ UPDATED: Remove isUpcoming reference - allow joining active programs
            if (!hasUserJoined && canJoin && program.isActive) ...[
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  label: const Text('Join Program'),
                  onPressed: () => _joinProgram(context, participantProvider, authProvider),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // ✅ UPDATED: Remove isUpcoming reference - allow leaving active programs
            if (hasUserJoined && program.isActive) ...[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.exit_to_app, size: 20),
                  label: const Text('Leave Program'),
                  onPressed: () => _leaveProgram(context, participantProvider, authProvider),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 20),
                label: const Text('Share'),
                onPressed: _shareProgram,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.blue.shade600;
    if (percentage >= 25) return Colors.orange;
    return Colors.red;
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
        hasPaidContribution: program.suggestedContribution == null, // If no suggested amount, consider as paid
      );

      await participantProvider.joinProgram(participant);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the program!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join program: $e')),
      );
    }
  }

  void _leaveProgram(BuildContext context, ParticipantProvider participantProvider, AppAuthProvider authProvider) async {
    try {
      final currentUser = authProvider.user;
      if (currentUser == null) return;
      
      await participantProvider.leaveProgram(program.programId, currentUser.uid);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left the program successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave program: $e')),
      );
    }
  }

  void _shareProgram() {
    // Implement share functionality
    print('Share program: ${program.title}');
  }
}