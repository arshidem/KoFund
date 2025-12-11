import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../auth/providers/app_auth_provider.dart';

class ProgramContributionsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramContributionsTab({super.key, required this.program});

  @override
  State<ProgramContributionsTab> createState() => _ProgramContributionsTabState();
}

class _ProgramContributionsTabState extends State<ProgramContributionsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMethod = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Check if current user is admin
  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    
    if (currentUser == null) return false;
    
    // 1. Program creator is always admin
    if (currentUser.uid == widget.program.createdBy) {
      return true;
    }
    
    // 2. User with 'admin' role
    if (currentUser.role == 'admin') {
      return true;
    }
    
    // 3. User with isAdmin flag and approved
    if (currentUser.isAdmin == true && currentUser.isApproved == true) {
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin(context);
    
    return Column(
      children: [
        // Contribution Summary
        _buildContributionSummary(context),
        
        // Search and Filter Bar
        _buildSearchFilterBar(),
        
        // Contributions List
        Expanded(
          child: StreamBuilder<List<ContributionModel>>(
            stream: Provider.of<ContributionProvider>(context, listen: false)
                .streamProgramContributions(widget.program.programId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final contributions = snapshot.data ?? [];
              final filteredContributions = _filterContributions(contributions);

              if (filteredContributions.isEmpty) {
                return _buildEmptyState(contributions.isEmpty);
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredContributions.length,
                itemBuilder: (context, index) {
                  final contribution = filteredContributions[index];
                  return _buildContributionCard(contribution, context, isAdmin);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContributionSummary(BuildContext context) {
    return StreamBuilder<double>(
      stream: Provider.of<ContributionProvider>(context, listen: false)
          .streamProgramTotalContributions(widget.program.programId),
      builder: (context, totalSnapshot) {
        final totalCollected = totalSnapshot.data ?? 0.0;
        
        // FIXED: Use program's estimatedTotalAmount instead of calculating manually
        final totalExpected = widget.program.estimatedTotalAmount;
        final progressPercentage = widget.program.calculateProgress(totalCollected);

        return StreamBuilder<List<ContributionModel>>(
          stream: Provider.of<ContributionProvider>(context, listen: false)
              .streamProgramContributions(widget.program.programId),
          builder: (context, contributionsSnapshot) {
            final contributions = contributionsSnapshot.data ?? [];
            final totalCount = contributions.length;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Main Contribution Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Collected',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${totalCollected.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Expected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${totalExpected.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: totalExpected > 0 ? totalCollected / totalExpected : 0,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progressPercentage)),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${progressPercentage.toStringAsFixed(1)}% collected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '₹ ${(totalExpected - totalCollected).toStringAsFixed(2)} remaining',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // ✅ SIMPLIFIED: Status Breakdown - All contributions are completed
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Total', totalCount.toString(), Icons.payments, Colors.blue),
                          _buildStatItem('Completed', totalCount.toString(), Icons.check_circle, Colors.green),
                          _buildStatItem('Amount', '₹${totalCollected.toStringAsFixed(0)}', Icons.attach_money, Colors.green),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contributions...',
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
          const SizedBox(height: 12),
          
          // ✅ SIMPLIFIED: Only payment method filter
          Row(
            children: [
              // Payment Method Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterMethod,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Methods')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'online', child: Text('Online')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterMethod = value!;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(ContributionModel contribution, BuildContext context, bool isAdmin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2), // ✅ Always green
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle, // ✅ Always check icon
            color: Colors.green,
          ),
        ),
        title: FutureBuilder<String>(
          future: _getUserName(contribution.userId, context),
          builder: (context, snapshot) {
            final userName = snapshot.data ?? 'User';
            return Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatPaymentMethod(contribution.paymentMethod)} • ${DateFormat('MMM dd, yyyy').format(contribution.createdAt.toDate())}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹ ${contribution.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Chip(
              label: const Text(
                'Paid', // ✅ Always "Paid"
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: Colors.green, // ✅ Always green
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        onTap: isAdmin ? () {
          _showContributionActions(contribution, context);
        } : null,
      ),
    );
  }

  Widget _buildEmptyState(bool noContributions) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noContributions ? Icons.payments_outlined : Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            noContributions ? 'No Contributions Yet' : 'No Matching Contributions',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noContributions 
                ? 'Contributions will appear here when participants make payments'
                : 'Try adjusting your search or filters',
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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
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

  List<ContributionModel> _filterContributions(List<ContributionModel> contributions) {
    List<ContributionModel> filtered = contributions;

    // ✅ SIMPLIFIED: Only apply payment method filter
    if (_filterMethod != 'all') {
      filtered = filtered.where((contribution) => contribution.paymentMethod == _filterMethod).toList();
    }

    return filtered;
  }

  Future<String> _getUserName(String userId, BuildContext context) async {
    // You'll need to implement this method to get user name from user service
    // For now, return a placeholder
    return 'User $userId';
  }

  // ✅ SIMPLIFIED: Only show view details and delete actions
  void _showContributionActions(ContributionModel contribution, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showContributionDetails(contribution, context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Contribution'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(contribution, context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showContributionDetails(ContributionModel contribution, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contribution Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<String>(
                future: _getUserName(contribution.userId, context),
                builder: (context, snapshot) {
                  return _buildDetailRow('User', snapshot.data ?? 'User ${contribution.userId}');
                },
              ),
              _buildDetailRow('Amount', '₹ ${contribution.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Payment Method', _formatPaymentMethod(contribution.paymentMethod)),
              _buildDetailRow('Status', 'Completed'), // ✅ Always "Completed"
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy - HH:mm').format(contribution.createdAt.toDate())),
              _buildDetailRow('Contribution ID', contribution.contributionId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  // ✅ REMOVED: _updateContributionStatus method

  void _showDeleteConfirmation(ContributionModel contribution, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: Text('Are you sure you want to delete this contribution of ₹ ${contribution.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContribution(contribution, context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteContribution(ContributionModel contribution, BuildContext context) async {
    try {
      final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
      await contributionProvider.deleteContribution(contribution.contributionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete contribution: $e')),
      );
    }
  }

  // ✅ REMOVED: _getStatusColor method
  // ✅ REMOVED: _getStatusIcon method
  // ✅ REMOVED: _formatStatus method

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method;
    }
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.blue.shade600;
    if (percentage >= 25) return Colors.orange;
    return Colors.red;
  }
}