// edit_contribution_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../contributions/models/contribution_model.dart';
import '../../contributions/providers/contribution_provider.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../programs/models/program_model.dart';
import '../../programs/providers/program_provider.dart';
import '../widgets/custom_text_field.dart';

class EditContributionScreen extends StatefulWidget {
  final String contributionId;
  final Function(ContributionModel?) onSave;

  const EditContributionScreen({
    Key? key,
    required this.contributionId,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditContributionScreenState createState() => _EditContributionScreenState();
}

class _EditContributionScreenState extends State<EditContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _editReasonController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

  // Form values
  String _paymentMethod = '';
  String? _monthId;
  bool _isMonthly = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // NEW: Program selection
  String? _selectedProgramId;
  List<ProgramModel> _availablePrograms = [];
  
  // Store fetched contribution
  ContributionModel? _contribution;

  // Available payment methods
  final List<String> _paymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Credit Card',
    'Debit Card',
    'Other',
  ];

  // Available months for selection
  final List<String> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _generateAvailableMonths();
    _fetchContributionAndPrograms();
  }

  Future<void> _fetchContributionAndPrograms() async {
    try {
      print('🔄 Fetching contribution with ID: ${widget.contributionId}');
      
      // First try with the given ID
      var docRef = FirebaseFirestore.instance
          .collection('contributions')
          .doc(widget.contributionId);
      
      var snapshot = await docRef.get();
      
      // If not found, try adding 'contrib_' prefix
      if (!snapshot.exists && !widget.contributionId.startsWith('contrib_')) {
        print('⚠️ Not found, trying with "contrib_" prefix...');
        docRef = FirebaseFirestore.instance
            .collection('contributions')
            .doc('contrib_${widget.contributionId}');
        snapshot = await docRef.get();
      }
      
      if (!snapshot.exists) {
        throw Exception('Contribution not found with ID: ${widget.contributionId}');
      }
      
      final data = snapshot.data();
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Contribution data is invalid');
      }
      
      // Create ContributionModel from Firestore data
      _contribution = ContributionModel.fromMap(data, snapshot.id);
      
      print('✅ Contribution fetched successfully');
      print('   Amount: ${_contribution!.amount}');
      print('   Payment Method: ${_contribution!.paymentMethod}');
      print('   Program ID: ${_contribution!.programId}');
      print('   Community ID: ${_contribution!.communityId}');
      
      // Fetch available programs for this community
      await _fetchAvailablePrograms(_contribution!.communityId);
      
      // Initialize form values
      _amountController.text = _contribution!.amount.toStringAsFixed(2);
      _paymentMethod = _contribution!.paymentMethod;
      _selectedProgramId = _contribution!.programId;
      _noteController.text = _contribution!.note ?? '';
      _isMonthly = _contribution!.isMonthlyContribution;
      _monthId = _contribution!.monthId;
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Error fetching contribution: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchAvailablePrograms(String communityId) async {
    try {
      print('📋 Fetching programs for community: $communityId');
      
      // Use the FirebaseFirestore directly since ProgramProvider doesn't have getProgramsByCommunity
      final querySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('programs')
          .where('status', whereIn: ['active', 'ongoing'])
          .get();
      
      _availablePrograms = querySnapshot.docs.map((doc) {
        // Use ProgramModel.fromMap with the data
        return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      print('✅ Found ${_availablePrograms.length} programs');
      
      // If no programs found in subcollection, try root programs collection
      if (_availablePrograms.isEmpty) {
        print('⚠️ No programs in subcollection, trying root collection...');
        final rootQuery = await FirebaseFirestore.instance
            .collection('programs')
            .where('communityId', isEqualTo: communityId)
            .where('status', whereIn: ['active', 'ongoing'])
            .get();
        
        _availablePrograms = rootQuery.docs.map((doc) {
          return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        print('✅ Found ${_availablePrograms.length} programs in root collection');
      }
      
      // Ensure the current program is in the list
      if (_contribution != null && !_availablePrograms.any((p) => p.programId == _contribution!.programId)) {
        // Try to fetch the specific program to add to list
        try {
          // Try community subcollection first
          final programDoc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('programs')
              .doc(_contribution!.programId)
              .get();
          
          if (programDoc.exists) {
            final program = ProgramModel.fromMap(programDoc.data() as Map<String, dynamic>, programDoc.id);
            _availablePrograms.add(program);
            print('➕ Added current program from subcollection');
          } else {
            // Try root collection
            final rootProgramDoc = await FirebaseFirestore.instance
                .collection('programs')
                .doc(_contribution!.programId)
                .get();
            
            if (rootProgramDoc.exists) {
              final program = ProgramModel.fromMap(rootProgramDoc.data() as Map<String, dynamic>, rootProgramDoc.id);
              _availablePrograms.add(program);
              print('➕ Added current program from root collection');
            }
          }
        } catch (e) {
          print('⚠️ Could not fetch current program: $e');
        }
      }
      
      // Sort programs by name
      _availablePrograms.sort((a, b) => a.title.compareTo(b.title));
      
    } catch (e) {
      print('❌ Error fetching programs: $e');
      _availablePrograms = [];
    }
  }

  void _generateAvailableMonths() {
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthId = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      _availableMonths.add(monthId);
    }
  }

  String _formatMonthId(String monthId) {
    try {
      final parts = monthId.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        final date = DateTime(int.parse(year), month, 1);
        return DateFormat('MMM yyyy').format(date);
      }
    } catch (e) {
      return monthId;
    }
    return monthId;
  }

  // Helper function to get program name by ID
  String _getProgramNameById(String programId) {
    try {
      final program = _availablePrograms.firstWhere(
        (p) => p.programId == programId,
        orElse: () => ProgramModel(
          programId: programId,
          communityId: _contribution?.communityId ?? '',
          title: 'Program $programId',
          description: '',
          programDate: DateTime.now(),
          location: '',
          maxParticipants: 0,
          participantType: 'fixed',
          status: 'active',
          createdBy: '',
          createdAt: Timestamp.now(),
          programType: 'general',
          isMonthlyPaymentProgram: false,
        ),
      );
      return program.title;
    } catch (e) {
      return 'Program $programId';
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_contribution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contribution data not loaded'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // SAFE: Parse amount
    final amountText = _amountController.text;
    final newAmount = double.tryParse(amountText) ?? 0.0;

    // Check if there are actual changes
    bool hasChanges = newAmount != _contribution!.amount ||
        _paymentMethod != _contribution!.paymentMethod ||
        _selectedProgramId != _contribution!.programId ||
        _noteController.text.trim() != (_contribution!.note ?? '') ||
        _isMonthly != _contribution!.isMonthlyContribution ||
        _monthId != _contribution!.monthId;

    if (!hasChanges) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes detected'),
          backgroundColor: Colors.orange,
        ),
      );
      widget.onSave(null);
      return;
    }

    // Show confirmation dialog if amount or program changed
    if (newAmount != _contribution!.amount || _selectedProgramId != _contribution!.programId) {
      String changes = '';
      
      if (newAmount != _contribution!.amount) {
        final difference = newAmount - _contribution!.amount;
        changes += 'Amount: ₹${_contribution!.amount.toStringAsFixed(2)} → ₹${newAmount.toStringAsFixed(2)} (${difference > 0 ? '+' : ''}₹${difference.abs().toStringAsFixed(2)})\n';
      }
      
      if (_selectedProgramId != _contribution!.programId) {
        final oldProgramName = _getProgramNameById(_contribution!.programId);
        final newProgramName = _getProgramNameById(_selectedProgramId!);
        
        changes += 'Program: $oldProgramName → $newProgramName\n';
      }
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Changes'),
          content: Text(
            'You are making the following changes:\n\n$changes\nPlease provide a reason for these changes:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    try {
      // Get current user info
      final authProvider = context.read<AppAuthProvider>();
      final currentUser = authProvider.user;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create updated contribution model
      final updatedContribution = _contribution!.copyWith(
        contributionId: widget.contributionId,
        amount: newAmount,
        paymentMethod: _paymentMethod,
        programId: _selectedProgramId ?? _contribution!.programId,
        note: _noteController.text.trim(),
        isMonthlyContribution: _isMonthly,
        monthId: _isMonthly ? _monthId : null,
        editReason: _editReasonController.text.trim(),
      );

      // Call provider to update
      final contributionProvider = context.read<ContributionProvider>();
      await contributionProvider.updateContribution(
        updatedContribution,
        editedByUserId: currentUser.uid,
        editedByUserName: currentUser.displayName ?? 'Admin User',
        editReason: _editReasonController.text.trim(),
      );

      // Call onSave callback
      widget.onSave(updatedContribution);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contribution updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back
      Navigator.pop(context);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Contribution'),
        actions: [
          if (!_isLoading && !_hasError)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading contribution',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchContributionAndPrograms,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Contribution ID info
                        Card(
                          color: Colors.grey[100],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.info, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Contribution ID: ${widget.contributionId}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Original Amount Info
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Original Amount:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '₹${_contribution!.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Program Selection Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Program *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedProgramId,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              items: _availablePrograms.map((program) {
                                return DropdownMenuItem<String>(
                                  value: program.programId,
                                  child: Text(program.title),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedProgramId = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a program';
                                }
                                return null;
                              },
                              hint: const Text('Select Program'),
                            ),
                            if (_availablePrograms.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'No active programs found in this community',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Amount Field
                        CustomTextField(
                          label: 'Amount *',
                          controller: _amountController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Payment Method Dropdown - AUTO-FILLED
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Method *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _paymentMethod.isNotEmpty && _paymentMethods.contains(_paymentMethod) 
                                  ? _paymentMethod 
                                  : null,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              items: _paymentMethods.map((method) {
                                return DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(method),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _paymentMethod = value);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select payment method';
                                }
                                return null;
                              },
                              hint: const Text('Select Payment Method'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Monthly Contribution Toggle
                        SwitchListTile(
                          title: const Text('Monthly Contribution'),
                          subtitle: Text(_isMonthly
                              ? 'This is a recurring monthly contribution'
                              : 'This is a one-time contribution'),
                          value: _isMonthly,
                          onChanged: (value) {
                            setState(() => _isMonthly = value ?? false);
                          },
                        ),

                        // Month Selection (only for monthly)
                        if (_isMonthly) ...[
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Month *',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _monthId,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                ),
                                items: _availableMonths.map((monthId) {
                                  return DropdownMenuItem(
                                    value: monthId,
                                    child: Text(_formatMonthId(monthId)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _monthId = value);
                                },
                                validator: (value) {
                                  if (_isMonthly && (value == null || value.isEmpty)) {
                                    return 'Please select month';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Note Field
                        CustomTextField(
                          label: 'Note (Optional)',
                          controller: _noteController,
                          maxLines: 3,
                          hintText: 'Add any additional notes...',
                        ),

                        const SizedBox(height: 16),

                        // Edit Reason Field
                        CustomTextField(
                          label: 'Reason for Edit *',
                          controller: _editReasonController,
                          maxLines: 2,
                          hintText: 'Why are you making these changes?',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please provide a reason for editing';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Changes Summary
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Changes Summary',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildChangeItem(
                                  'Amount',
                                  '₹${_contribution!.amount.toStringAsFixed(2)}',
                                  '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
                                ),
                                _buildChangeItem(
                                  'Payment Method',
                                  _contribution!.paymentMethod,
                                  _paymentMethod,
                                ),
                                _buildChangeItem(
                                  'Program',
                                  _getProgramNameById(_contribution!.programId),
                                  _selectedProgramId != null
                                      ? _getProgramNameById(_selectedProgramId!)
                                      : _getProgramNameById(_contribution!.programId),
                                ),
                                if (_noteController.text.trim() != (_contribution!.note ?? ''))
                                  _buildChangeItem(
                                    'Note',
                                    _contribution!.note ?? 'None',
                                    _noteController.text.trim(),
                                    isText: true,
                                  ),
                                if (_isMonthly != _contribution!.isMonthlyContribution)
                                  _buildChangeItem(
                                    'Type',
                                    _contribution!.isMonthlyContribution
                                        ? 'Monthly'
                                        : 'One-time',
                                    _isMonthly ? 'Monthly' : 'One-time',
                                  ),
                                if (_isMonthly && _monthId != _contribution!.monthId)
                                  _buildChangeItem(
                                    'Month',
                                    _contribution!.monthId != null
                                        ? _formatMonthId(_contribution!.monthId!)
                                        : 'None',
                                    _monthId != null ? _formatMonthId(_monthId!) : 'None',
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  widget.onSave(null);
                                  Navigator.pop(context);
                                },
                                child: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveChanges,
                                child: const Text('Save Changes'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildChangeItem(String label, String oldValue, String newValue,
      {bool isText = false}) {
    final hasChanged = oldValue != newValue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oldValue,
                  style: TextStyle(
                    color: hasChanged ? Colors.red : Colors.grey[600],
                    decoration:
                        hasChanged ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (hasChanged)
                  Text(
                    '→ $newValue',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _editReasonController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}