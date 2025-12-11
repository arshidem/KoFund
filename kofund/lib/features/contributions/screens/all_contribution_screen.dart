// lib/features/contributions/screens/all_contribution_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/auth/providers/app_auth_provider.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/programs/models/program_model.dart';
import '../providers/contribution_provider.dart';
import '../models/contribution_model.dart';
import 'update_contribution_screen.dart';
import 'add_contribution_screen.dart';
import '../../../routing/route_names.dart';

class AllContributionsScreen extends StatefulWidget {
  const AllContributionsScreen({super.key});

  @override
  State<AllContributionsScreen> createState() => _AllContributionsScreenState();
}

class _AllContributionsScreenState extends State<AllContributionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Filter variables
  String _selectedProgram = 'all';
  String _selectedParticipant = 'all';
  String _selectedPaymentMethod = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  // Cache for program and user data
  final Map<String, ProgramModel> _programsCache = {};
  final Map<String, UserModel> _usersCache = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final contributionProvider = context.read<ContributionProvider>();
    final currentUser = context.read<AppAuthProvider>().user;
    
    if (currentUser != null && currentUser.communityId != null) {
      contributionProvider.loadCommunityContributions(currentUser.communityId!);
    }
  }

  void _navigateToUpdateContribution(ContributionModel contribution) {
    Navigator.pushNamed(
      context, 
      RouteNames.updateContribution,
      arguments: contribution,
    );
  }

  void _navigateToAddContribution() {
    Navigator.pushNamed(
      context, 
      RouteNames.addContribution,
    );
  }

  // Filter contributions based on selected filters
  List<ContributionModel> _getFilteredContributions(List<ContributionModel> contributions) {
    return contributions.where((contribution) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final program = _programsCache[contribution.programId];
        final user = _usersCache[contribution.userId];
        final programTitle = program?.title.toLowerCase() ?? '';
        final userName = user?.displayName?.toLowerCase() ?? '';
        final searchLower = _searchQuery.toLowerCase();
        
        if (!programTitle.contains(searchLower) && 
            !userName.contains(searchLower) &&
            !contribution.paymentMethod.toLowerCase().contains(searchLower)) {
          return false;
        }
      }

      // Program filter
      if (_selectedProgram != 'all' && contribution.programId != _selectedProgram) {
        return false;
      }

      // Participant filter
      if (_selectedParticipant != 'all' && contribution.userId != _selectedParticipant) {
        return false;
      }

      // Payment method filter
      if (_selectedPaymentMethod != 'all' && contribution.paymentMethod != _selectedPaymentMethod) {
        return false;
      }

      // Date range filter
      if (_startDate != null && contribution.createdAt.toDate().isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && contribution.createdAt.toDate().isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  void _showFiltersDialog() {
    final contributionProvider = context.read<ContributionProvider>();
    final currentUser = context.read<AppAuthProvider>().user;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Contributions'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Program Filter
                  _buildProgramFilter(contributionProvider, setDialogState),
                  
                  // Participant Filter
                  _buildParticipantFilter(contributionProvider, setDialogState),
                  
                  // Payment Method Filter
                  _buildPaymentMethodFilter(setDialogState),
                  
                  // Date Range Filter
                  _buildDateRangeFilter(setDialogState),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _selectedProgram = 'all';
                    _selectedParticipant = 'all';
                    _selectedPaymentMethod = 'all';
                    _startDate = null;
                    _endDate = null;
                  });
                },
                child: const Text('Reset All'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgramFilter(ContributionProvider provider, StateSetter setDialogState) {
    final programIds = provider.communityContributions.map((c) => c.programId).toSet();
    
    return FutureBuilder<List<ProgramModel>>(
      future: _loadPrograms(programIds.toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        
        final programs = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Program:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedProgram,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Programs')),
                ...programs.map((program) => DropdownMenuItem(
                  value: program.programId,
                  child: Text(program.title),
                )),
              ],
              onChanged: (value) {
                setDialogState(() => _selectedProgram = value!);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticipantFilter(ContributionProvider provider, StateSetter setDialogState) {
    final userIds = provider.communityContributions.map((c) => c.userId).toSet();
    
    return FutureBuilder<List<UserModel>>(
      future: _loadUsers(userIds.toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        
        final users = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Participant:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedParticipant,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Participants')),
                ...users.map((user) => DropdownMenuItem(
                  value: user.uid,
                  child: Text(user.displayName ?? 'Unknown User'),
                )),
              ],
              onChanged: (value) {
                setDialogState(() => _selectedParticipant = value!);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodFilter(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: _selectedPaymentMethod,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Methods')),
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'online', child: Text('Online')),
            DropdownMenuItem(value: 'upi', child: Text('UPI')),
            DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
          ],
          onChanged: (value) {
            setDialogState(() => _selectedPaymentMethod = value!);
          },
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setDialogState(() => _startDate = date);
                  }
                },
                child: Text(_startDate == null 
                    ? 'Start Date' 
                    : 'From: ${_startDate!.toString().split(' ')[0]}'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setDialogState(() => _endDate = date);
                  }
                },
                child: Text(_endDate == null 
                    ? 'End Date' 
                    : 'To: ${_endDate!.toString().split(' ')[0]}'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<List<ProgramModel>> _loadPrograms(List<String> programIds) async {
    final List<ProgramModel> programs = [];
    
    for (final programId in programIds) {
      if (_programsCache.containsKey(programId)) {
        programs.add(_programsCache[programId]!);
      } else {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('programs')
              .doc(programId)
              .get();
          
          if (doc.exists) {
            final program = ProgramModel.fromMap(doc.data()!, doc.id);
            _programsCache[programId] = program;
            programs.add(program);
          }
        } catch (e) {
          print('Error loading program $programId: $e');
        }
      }
    }
    
    return programs;
  }

  Future<List<UserModel>> _loadUsers(List<String> userIds) async {
    final List<UserModel> users = [];
    
    for (final userId in userIds) {
      if (_usersCache.containsKey(userId)) {
        users.add(_usersCache[userId]!);
      } else {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (doc.exists) {
            final user = UserModel.fromMap(doc.data()!);
            _usersCache[userId] = user;
            users.add(user);
          }
        } catch (e) {
          print('Error loading user $userId: $e');
        }
      }
    }
    
    return users;
  }

  void _showAdminActions(ContributionModel contribution) {
    final isAdmin = context.read<AppAuthProvider>().user?.isAdmin == true;
    
    if (!isAdmin) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Update Contribution'),
              onTap: () {
                Navigator.pop(context);
                _navigateToUpdateContribution(contribution);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Contribution'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(contribution);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ContributionModel contribution) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: const Text('Are you sure you want to delete this contribution? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContribution(contribution);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteContribution(ContributionModel contribution) async {
    final provider = context.read<ContributionProvider>();
    
    try {
      await provider.deleteContribution(contribution.contributionId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting contribution: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contributionProvider = context.watch<ContributionProvider>();
    final currentUser = context.read<AppAuthProvider>().user;
    final isAdmin = currentUser?.isAdmin == true;

    final contributions = contributionProvider.communityContributions;
    final filteredContributions = _getFilteredContributions(contributions);

    return Scaffold(
      appBar: null, // No AppBar since it's inside a tab
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contributions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Filter Summary
          if (_hasActiveFilters())
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text('${filteredContributions.length} results'),
                    backgroundColor: Colors.blue[100],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _showFiltersDialog,
                    child: const Text('Edit Filters'),
                  ),
                ],
              ),
            ),

          // Loading Indicator
          if (contributionProvider.isLoading)
            const LinearProgressIndicator(),

          // Contributions List
          Expanded(
            child: contributionProvider.isLoading && contributions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredContributions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredContributions.length,
                        itemBuilder: (context, index) {
                          final contribution = filteredContributions[index];
                          return _buildContributionCard(contribution, isAdmin);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _navigateToAddContribution,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  bool _hasActiveFilters() {
    return _selectedProgram != 'all' ||
        _selectedParticipant != 'all' ||
        _selectedPaymentMethod != 'all' ||
        _startDate != null ||
        _endDate != null;
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No contributions found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'When contributions are made,\nthey will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(ContributionModel contribution, bool isAdmin) {
    return FutureBuilder(
      future: Future.wait([
        _loadPrograms([contribution.programId]),
        _loadUsers([contribution.userId]),
      ]),
      builder: (context, snapshot) {
        final programs = snapshot.hasData ? snapshot.data![0] : [];
        final users = snapshot.hasData ? snapshot.data![1] : [];
        
        // Safely extract program and user with proper typing
        final ProgramModel? program = programs.isNotEmpty ? programs.first : null;
        final UserModel? user = users.isNotEmpty ? users.first : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: _buildStatusIcon(contribution.status),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program?.title ?? 'Unknown Program',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.displayName ?? 'Unknown User',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: ₹${contribution.amount}'),
                Text('Method: ${contribution.paymentMethod}'),
                Text(
                  'Date: ${_formatDate(contribution.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: isAdmin
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showAdminActions(contribution),
                  )
                : null,
            onTap: isAdmin ? () => _showAdminActions(contribution) : null,
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(String status) {
    // Since all contributions are completed, always show green check icon
    return const Icon(Icons.check_circle, color: Colors.green);
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}