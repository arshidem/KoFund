// lib/features/profile/screens/participation_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/widgets/loading_indicator.dart';
import 'package:kofund/features/programs/constants/program_types.dart'; // ✅ ADD IMPORT

class ParticipationHistoryScreen extends StatefulWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  State<ParticipationHistoryScreen> createState() =>
      _ParticipationHistoryScreenState();
}

class _ParticipationHistoryScreenState
    extends State<ParticipationHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadParticipationHistory();
  }

  Future<void> _loadParticipationHistory() async {
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.getUserParticipationHistory();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final participationHistory = profileProvider.participationHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Programs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadParticipationHistory,
        child: _buildContent(profileProvider, participationHistory),
      ),
    );
  }

  Widget _buildContent(
    ProfileProvider profileProvider,
    List<Map<String, dynamic>> participationHistory,
  ) {
    if (profileProvider.isLoading) {
      return const LoadingIndicator();
    }

    if (profileProvider.error != null) {
      return _buildErrorState(profileProvider.error!);
    }

    if (participationHistory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: participationHistory.length,
      itemBuilder: (context, index) {
        final participation = participationHistory[index];
        return _buildParticipationCard(participation);
      },
    );
  }

  Widget _buildParticipationCard(Map<String, dynamic> participation) {
    final programTitle = participation['programTitle'] ?? 'Unnamed Program';
    final programType = participation['programType'] ?? ProgramTypes.general; // ✅ USE CONSTANT
    final joinedAt = _parseDate(participation['joinedAt']);
    final hasPaid = participation['hasPaidContribution'] ?? false;
    final contributionPaid = (participation['contributionPaid'] ?? 0).toDouble();
    final suggestedContribution = (participation['suggestedContribution'] ?? 0).toDouble();
    final progressPercentage = (participation['progressPercentage'] ?? 0).toDouble();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildProgramIcon(programType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(joinedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasPaid ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    hasPaid ? 'Paid' : 'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Program Type
            _buildDetailRow('Type', ProgramTypes.getDisplayName(programType)), // ✅ USE getDisplayName

            // Contribution info
            if (suggestedContribution > 0) ...[
              const SizedBox(height: 8),
              _buildContributionInfo(
                contributionPaid,
                suggestedContribution,
                hasPaid,
                progressPercentage,
              ),
            ] else ...[
              const SizedBox(height: 8),
              _buildNoContributionInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramIcon(String programType) {
    // ✅ USE ProgramTypes.getIconData INSTEAD OF HARCODED MAPPING
    final iconData = ProgramTypes.getIconData(programType);

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.blue[100],
      child: Icon(iconData, color: Colors.blue, size: 20),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionInfo(
    double paid,
    double suggested,
    bool hasPaid,
    double progressPercentage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Contribution Progress',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${progressPercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasPaid ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '₹${paid.toStringAsFixed(2)} / ₹${suggested.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: hasPaid ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progressPercentage / 100,
          backgroundColor: Colors.grey[200],
          color: hasPaid ? Colors.green : Colors.orange,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasPaid ? 'Fully Paid' : 'Payment Pending',
              style: TextStyle(
                fontSize: 10,
                color: hasPaid ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!hasPaid)
              Text(
                '₹${(suggested - paid).toStringAsFixed(2)} remaining',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoContributionInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No contribution required for this program',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_note, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No Program Participations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'You haven\'t joined any programs yet. Start participating in community programs to see them here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to programs screen
                  // Navigator.pushNamed(context, '/programs');
                },
                icon: const Icon(Icons.explore),
                label: const Text('Browse Programs'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Unable to Load Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadParticipationHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is DateTime) {
      return date;
    } else {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ✅ REMOVED: _capitalize method since we're using ProgramTypes.getDisplayName
}