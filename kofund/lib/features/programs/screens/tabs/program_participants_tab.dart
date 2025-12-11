import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp if needed
import '../../models/program_model.dart';
import '../../providers/program_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../participants/providers/participant_provider.dart';

class ProgramParticipantsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramParticipantsTab({super.key, required this.program});

  @override
  State<ProgramParticipantsTab> createState() => _ProgramParticipantsTabState();
}

class _ProgramParticipantsTabState extends State<ProgramParticipantsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Participants Stats
        _buildParticipantsStats(context),
        
        // Search and Filter Bar
        _buildSearchFilterBar(),
        
        // Participants List
  // Participants List - UPDATE THIS SECTION
Expanded(
  child: StreamBuilder<List<ParticipantModel>>(
    // ✅ CHANGED: Use ProgramProvider instead of ParticipantProvider
    stream: Provider.of<ProgramProvider>(context, listen: false)
        .streamProgramParticipantsWithContributions(widget.program.programId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 48),
              SizedBox(height: 8),
              Text('Error loading participants'),
              SizedBox(height: 8),
              Text(
                '${snapshot.error}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      final participants = snapshot.data ?? [];
      final filteredParticipants = _filterParticipants(participants);

      if (filteredParticipants.isEmpty) {
        return _buildEmptyState(participants.isEmpty);
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredParticipants.length,
        itemBuilder: (context, index) {
          final participant = filteredParticipants[index];
          return _buildParticipantCard(participant, context);
        },
      );
    },
  ),
),
      ],
    );
  }

Widget _buildParticipantsStats(BuildContext context) {
  return StreamBuilder<Map<String, dynamic>>(
    stream: Provider.of<ProgramProvider>(context, listen: false)
        .streamProgramFinancialSummary(widget.program.programId),
    builder: (context, snapshot) {
      final data = snapshot.data ?? {
        'totalParticipants': 0,
        'paidParticipants': 0,
        'pendingParticipants': 0,
        'totalCollected': 0.0,
        'totalExpected': 0.0,
        'collectionRate': 0.0, // ✅ ADDED: Ensure this exists
      };

      // ✅ CALCULATE: collectionRate if not provided
      final totalExpected = data['totalExpected'] ?? 0.0;
      final totalCollected = data['totalCollected'] ?? 0.0;
      final collectionRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', data['totalParticipants'].toString(), Icons.people, Colors.blue),
                    _buildStatItem('Paid', data['paidParticipants'].toString(), Icons.check_circle, Colors.green),
                    _buildStatItem('Pending', data['pendingParticipants'].toString(), Icons.pending, Colors.orange),
                  ],
                ),
                SizedBox(height: 12),
                if (widget.program.suggestedContribution != null && widget.program.suggestedContribution! > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Collected', '₹${totalCollected.toStringAsFixed(0)}', Icons.payments, Colors.green),
                      _buildStatItem('Expected', '₹${totalExpected.toStringAsFixed(0)}', Icons.attach_money, Colors.blue),
                      _buildStatItem('Rate', '${collectionRate.toStringAsFixed(1)}%', Icons.trending_up, Colors.purple),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildSearchFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search participants...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          // Filter Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterStatus = value!;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {
  final userName = participant.userName.isNotEmpty ? participant.userName : 'Unknown User';
  final userEmail = participant.userEmail.isNotEmpty ? participant.userEmail : 'No email';
  final joinedAt = participant.joinedAt ?? DateTime.now();
  final contributionPaid = participant.contributionPaid ?? 0;
  final suggestedContribution = widget.program.suggestedContribution ?? 0;
  final hasPaid = participant.hasPaidContribution;

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 1,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Text(
          userName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(userEmail),
          Text(
            'Joined: ${DateFormat('MMM dd, yyyy').format(joinedAt)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          // ✅ ADDED: Contribution progress
          if (suggestedContribution > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  'Paid: ₹${contributionPaid.toStringAsFixed(2)} / ₹${suggestedContribution.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasPaid ? Colors.green : Colors.orange,
                  ),
                ),
                SizedBox(height: 2),
                LinearProgressIndicator(
                  value: suggestedContribution > 0 ? (contributionPaid / suggestedContribution).clamp(0.0, 1.0) : 0,
                  backgroundColor: Colors.grey[200],
                  color: hasPaid ? Colors.green : Colors.orange,
                  minHeight: 4,
                ),
              ],
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (suggestedContribution > 0)
            Text(
              '₹${contributionPaid.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: hasPaid ? Colors.green : Colors.orange,
              ),
            ),
          const SizedBox(height: 4),
          Chip(
            label: Text(
              hasPaid ? 'Paid' : 'Pending',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: hasPaid ? Colors.green : Colors.orange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      onTap: () {
        _showParticipantActions(participant, context);
      },
    ),
  );
}

  Widget _buildEmptyState(bool noParticipants) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noParticipants ? Icons.people_outline : Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            noParticipants ? 'No Participants Yet' : 'No Matching Participants',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noParticipants 
                ? 'Participants will appear here when they join the program'
                : 'Try adjusting your search or filter',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

Widget _buildStatItem(String title, String value, IconData icon, Color color) {
  return Column(
    children: [
      Icon(icon, color: color, size: 24), // ✅ CHANGED: Reduced from 30 to 24
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 16, // ✅ CHANGED: Reduced from 18 to 16
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

  List<ParticipantModel> _filterParticipants(List<ParticipantModel> participants) {
    List<ParticipantModel> filtered = participants;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((participant) =>
        participant.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        participant.userEmail.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply payment status filter
    if (_filterStatus == 'paid') {
      filtered = filtered.where((p) => p.hasPaidContribution).toList();
    } else if (_filterStatus == 'pending') {
      filtered = filtered.where((p) => !p.hasPaidContribution).toList();
    }

    return filtered;
  }

  void _showParticipantActions(ParticipantModel participant, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to user profile
                },
              ),
              // Show payment toggle only if program has suggested contribution
              if (widget.program.suggestedContribution != null && widget.program.suggestedContribution! > 0)
                ListTile(
                  leading: Icon(
                    participant.hasPaidContribution ? Icons.payment : Icons.payment_outlined,
                    color: participant.hasPaidContribution ? Colors.green : Colors.orange,
                  ),
                  title: Text(participant.hasPaidContribution ? 'Mark as Pending' : 'Mark as Paid'),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePaymentStatus(participant, context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                title: const Text('Remove from Program'),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveConfirmation(participant, context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _togglePaymentStatus(ParticipantModel participant, BuildContext context) {
    // You'll need to implement this method in your ParticipantService
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment status toggle for ${participant.userName}'),
      ),
    );
  }

  void _showRemoveConfirmation(ParticipantModel participant, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text('Are you sure you want to remove ${participant.userName} from this program?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeParticipant(participant, context);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _removeParticipant(ParticipantModel participant, BuildContext context) async {
    try {
      final participantProvider = Provider.of<ParticipantProvider>(context, listen: false);
      await participantProvider.leaveProgram(participant.programId, participant.userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${participant.userName} from program')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove participant: $e')),
      );
    }
  }
}