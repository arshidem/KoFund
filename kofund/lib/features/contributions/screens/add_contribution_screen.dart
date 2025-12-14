// lib/features/contributions/screens/add_contribution_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../features/auth/providers/app_auth_provider.dart';
import '../../../features/programs/models/program_model.dart';
import '../../../features/participants/providers/participant_provider.dart';
import '../../../features/participants/models/participant_model.dart';
import '../providers/contribution_provider.dart';
import '../models/contribution_model.dart';

class AddContributionScreen extends StatefulWidget {
  const AddContributionScreen({super.key});

  @override
  State<AddContributionScreen> createState() => _AddContributionScreenState();
}

class _AddContributionScreenState extends State<AddContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedProgramId = '';
  String _selectedUserId = '';
  String _selectedPaymentMethod = 'cash';
  String _searchQuery = '';
  
  // ✅ ADD: For monthly tracking
  bool _isMonthlyProgram = false;
  String? _selectedMonth; // Format: "2025-01"
  List<String> _availableMonths = [];

  List<ProgramModel> _programs = [];
  List<ParticipantModel> _programParticipants = [];
  List<ParticipantModel> _filteredParticipants = [];
  bool _isLoading = false;
  double _suggestedContribution = 0;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterParticipants();
    });
  }

  void _filterParticipants() {
    if (_searchQuery.isEmpty) {
      _filteredParticipants = _programParticipants;
    } else {
      _filteredParticipants = _programParticipants.where((participant) {
        final userName = participant.userName.toLowerCase();
        final userEmail = participant.userEmail.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return userName.contains(query) || userEmail.contains(query);
      }).toList();
    }
  }

  Future<void> _loadPrograms() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = context.read<AppAuthProvider>().user;
      if (currentUser?.communityId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('programs')
          .where('communityId', isEqualTo: currentUser!.communityId)
          .where('status', isEqualTo: 'active')
          .get();

      // ✅ ADD: Debug all programs with more details
      print('=== LOADING ALL PROGRAMS ===');
      print('Community ID: ${currentUser.communityId}');
      print('Total programs found: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('\n📋 Program: ${data['title']}');
        print('   📍 ID: ${doc.id}');
        print('   📊 Status: ${data['status']}');
        print('   💰 Suggested: ${data['suggestedContribution']}');
        
        // ✅ Check if the field exists in Firestore
        if (data.containsKey('isMonthlyPaymentProgram')) {
          print('   📅 isMonthlyPaymentProgram: ${data['isMonthlyPaymentProgram']} (found in Firestore)');
        } else {
          print('   ❌ isMonthlyPaymentProgram: FIELD NOT FOUND in Firestore');
          print('   ⚠️ Defaulting to: false');
        }
        
        final program = ProgramModel.fromMap(data, doc.id);
        print('   ✅ Parsed isMonthlyPaymentProgram: ${program.isMonthlyPaymentProgram}');
        print('---');
      }
      
      setState(() {
        _programs = snapshot.docs
            .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      print('Error loading programs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ ADD: Load participants method (this was missing!)
  Future<void> _loadParticipants(String programId) async {
    setState(() => _isLoading = true);
    
    try {
      final participantProvider = context.read<ParticipantProvider>();
      await participantProvider.loadProgramParticipants(programId);
      
      // Get program details
      final programDoc = await FirebaseFirestore.instance
          .collection('programs')
          .doc(programId)
          .get();
      
      if (programDoc.exists) {
        final programData = programDoc.data()!;
        final program = ProgramModel.fromMap(programData, programId);
        
        // ✅ ADD DEBUG PRINTS
        print('=== LOADING PARTICIPANTS FOR PROGRAM ===');
        print('Program Title: ${program.title}');
        print('isMonthlyPaymentProgram: ${program.isMonthlyPaymentProgram}');
        
        setState(() {
          _suggestedContribution = program.suggestedContribution ?? 0;
          _isMonthlyProgram = program.isMonthlyPaymentProgram; // ✅ Get monthly flag
          
          // ✅ If monthly program, generate month options
          if (_isMonthlyProgram) {
            print('✅ This is a MONTHLY program - showing month selector');
            _availableMonths = _generateMonthOptions();
            _selectedMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
            print('Available months: $_availableMonths');
            print('Selected month: $_selectedMonth');
          } else {
            print('❌ This is NOT a monthly program');
          }
        });
      }
      
      setState(() {
        _programParticipants = participantProvider.programParticipants
            .where((participant) => participant.status == 'joined')
            .toList();
        _filteredParticipants = _programParticipants;
        _searchController.clear();
        _searchQuery = '';
      });
    } catch (e) {
      print('Error loading participants: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading participants: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ ADD: Generate available months for selection
  List<String> _generateMonthOptions() {
    final List<String> months = [];
    final now = DateTime.now();
    
    // Generate previous 3 months, current month, and next 3 months
    for (int i = -3; i <= 3; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      final monthStr = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      months.add(monthStr);
    }
    
    return months;
  }

  // ✅ UPDATED: _addContribution method with monthly support
  Future<void> _addContribution() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgramId.isEmpty || _selectedUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select program and participant')),
      );
      return;
    }
    
    // ✅ ADD: Validate month selection for monthly programs
    if (_isMonthlyProgram && (_selectedMonth == null || _selectedMonth!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select month for monthly contribution')),
      );
      return;
    }

    final provider = context.read<ContributionProvider>();
    final currentUser = context.read<AppAuthProvider>().user;

    // ✅ UPDATED: Create contribution with monthly data
    final contribution = ContributionModel(
      contributionId: '', // Will be generated by Firestore
      programId: _selectedProgramId,
      userId: _selectedUserId,
      communityId: currentUser?.communityId ?? '',
      amount: double.parse(_amountController.text),
      paymentMethod: _selectedPaymentMethod,
      // ✅ SET: Monthly fields based on program type
      isMonthlyContribution: _isMonthlyProgram, // true if monthly program
      monthId: _isMonthlyProgram ? _selectedMonth : null, // only set if monthly
      createdAt: Timestamp.now(),
    );

    try {
      await provider.addContribution(contribution);
      
      // Update participant's payment status
      await _updateParticipantPaymentStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contribution added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding contribution: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateParticipantPaymentStatus() async {
    try {
      final participant = _programParticipants.firstWhere(
        (p) => p.userId == _selectedUserId,
      );
      
      final newContributionPaid = (participant.contributionPaid ?? 0) + double.parse(_amountController.text);
      final hasFullyPaid = newContributionPaid >= _suggestedContribution;
      
      await FirebaseFirestore.instance
          .collection('participants')
          .doc(participant.participantId)
          .update({
            'contributionPaid': newContributionPaid,
            'hasPaidContribution': hasFullyPaid,
          });
    } catch (e) {
      print('Error updating participant payment status: $e');
    }
  }

  // ✅ ADD: Month selector widget
  Widget _buildMonthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Month *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableMonths.length,
            itemBuilder: (context, index) {
              final month = _availableMonths[index];
              final isSelected = _selectedMonth == month;
              final isCurrentMonth = month == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    _getMonthDisplayName(month),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.blue,
                  backgroundColor: isCurrentMonth ? Colors.blue[50] : Colors.grey[100],
                  onSelected: (selected) {
                    setState(() => _selectedMonth = month);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getMonthDisplayName(String monthId) {
    final parts = monthId.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);
    
    // Show "Jan 2024" format
    final monthName = DateFormat('MMM').format(date);
    
    // Add "(Current)" for current month
    final currentMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
    final suffix = monthId == currentMonth ? " (Current)" : "";
    
    return "$monthName $year$suffix";
  }

  Widget _buildParticipantList() {
    if (_filteredParticipants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No active participants found for this program'
                  : 'No participants found for "$_searchQuery"',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        )
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search participants by name or email...',
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
          ),
        ),

        // Search results info
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Chip(
                  label: Text('${_filteredParticipants.length} found'),
                  backgroundColor: Colors.blue[100],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'for "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Participants List
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _filteredParticipants.length,
            itemBuilder: (context, index) {
              final participant = _filteredParticipants[index];
              final hasPaid = participant.hasPaidContribution;
              final amountPaid = participant.contributionPaid ?? 0;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: hasPaid ? Colors.green[100] : Colors.blue[100],
                  child: Icon(
                    hasPaid ? Icons.check : Icons.person,
                    color: hasPaid ? Colors.green : Colors.blue,
                    size: 20,
                  ),
                ),
                title: Text(
                  participant.userName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    decoration: hasPaid ? TextDecoration.lineThrough : null,
                    color: hasPaid ? Colors.grey : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.userEmail,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasPaid 
                          ? 'Fully paid (₹$amountPaid)'
                          : 'Paid: ₹$amountPaid / ₹$_suggestedContribution',
                      style: TextStyle(
                        fontSize: 11,
                        color: hasPaid ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                trailing: _selectedUserId == participant.userId
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedUserId = participant.userId);
                },
                selected: _selectedUserId == participant.userId,
                selectedTileColor: Colors.blue[50],
              );
            },
          ),
        ),

        // Selected participant info
        if (_selectedUserId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected: ${_getSelectedParticipantName()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSelectedParticipantPaymentInfo(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getSelectedParticipantName() {
    final participant = _programParticipants.firstWhere(
      (p) => p.userId == _selectedUserId,
      orElse: () => ParticipantModel(
        participantId: '',
        programId: '',
        userId: '',
        userName: 'Unknown User',
        userEmail: '',
        communityId: '',
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: 0,
        hasPaidContribution: false,
      ),
    );
    return participant.userName;
  }

  String _getSelectedParticipantPaymentInfo() {
    final participant = _programParticipants.firstWhere(
      (p) => p.userId == _selectedUserId,
      orElse: () => ParticipantModel(
        participantId: '',
        programId: '',
        userId: '',
        userName: 'Unknown User',
        userEmail: '',
        communityId: '',
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: 0,
        hasPaidContribution: false,
      ),
    );
    
    if (participant.hasPaidContribution) {
      return 'Fully paid - ₹${participant.contributionPaid}';
    } else {
      return 'Paid: ₹${participant.contributionPaid ?? 0} / ₹$_suggestedContribution';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Contribution'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _addContribution,
            tooltip: 'Save Contribution',
          ),
        ],
      ),
      body: _isLoading && _programs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Program Selection
                    DropdownButtonFormField<String>(
                      value: _selectedProgramId.isEmpty ? null : _selectedProgramId,
                      decoration: const InputDecoration(
                        labelText: 'Select Program *',
                        border: OutlineInputBorder(),
                        hintText: 'Choose a program',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Choose a program'),
                        ),
                        ..._programs.map((program) => DropdownMenuItem(
                              value: program.programId,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    program.title,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '₹${program.suggestedContribution} • ${_formatDate(program.programDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  // ✅ ADD: Show monthly program badge
                                  if (program.isMonthlyPaymentProgram)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Monthly Program',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedProgramId = value!;
                          _selectedUserId = '';
                          _programParticipants.clear();
                          _filteredParticipants.clear();
                          _searchController.clear();
                          _suggestedContribution = 0;
                          _isMonthlyProgram = false; // Reset
                          _selectedMonth = null; // Reset
                          _availableMonths = []; // Reset
                        });
                        _loadParticipants(value!);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a program';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Program Info Card
                    if (_selectedProgramId.isNotEmpty)
                      Card(
                        color: _isMonthlyProgram ? Colors.green[50] : Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                _isMonthlyProgram ? Icons.calendar_month : Icons.info,
                                color: _isMonthlyProgram ? Colors.green : Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isMonthlyProgram 
                                          ? 'Monthly Program Contribution'
                                          : 'One-time Program Contribution',
                                      style: TextStyle(
                                        color: _isMonthlyProgram ? Colors.green : Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Suggested amount: ₹$_suggestedContribution',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _isMonthlyProgram ? Colors.green[700] : Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ✅ ADD: Month Selector for monthly programs
                    if (_isMonthlyProgram && _availableMonths.isNotEmpty) 
                      _buildMonthSelector(),

                    // Participants Section
                    if (_selectedProgramId.isNotEmpty) ...[
                      const Text(
                        'Select Participant *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildParticipantList(),
                      const SizedBox(height: 20),
                    ],

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount *',
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                        hintText: 'Enter contribution amount',
                        suffixText: _suggestedContribution > 0 
                            ? 'Suggested: ₹$_suggestedContribution'
                            : null,
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter valid amount';
                        }
                        return null;
                      },
                      // ✅ ADD: Auto-fill suggested amount
                      onTap: () {
                        if (_amountController.text.isEmpty && _suggestedContribution > 0) {
                          _amountController.text = _suggestedContribution.toString();
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Payment Method
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'online', child: Text('Online')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedPaymentMethod = value!);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select payment method';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Add Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addContribution,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _isMonthlyProgram ? Colors.green : Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(_isMonthlyProgram ? Icons.calendar_month : Icons.add),
                        label: Text(
                          _isMonthlyProgram ? 'Add Monthly Contribution' : 'Add Contribution',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}