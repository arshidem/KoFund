// lib/features/history/widgets/add_contribution_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/program_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../../features/contributions/models/contribution_model.dart';
import '../../../features/programs/models/program_model.dart';
import '../../../features/auth/models/user_model.dart';

class AddContributionModal extends StatefulWidget {
  const AddContributionModal({Key? key}) : super(key: key);

  @override
  State<AddContributionModal> createState() => _AddContributionModalState();
}

class _AddContributionModalState extends State<AddContributionModal> {
  final _contributionService = ContributionService();
  final _programService = ProgramService();
  final _userService = UserService();
  
  int _currentStep = 0;
  ProgramModel? _selectedProgram;
  UserModel? _selectedUser;
  double _amount = 0;
  String _paymentMethod = 'cash';
  final List<String> _paymentMethods = ['cash', 'online', 'bank transfer', 'other'];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final communityId = auth.user?.communityId ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 30), // Space to avoid camera notch
            
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Contribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _goToPreviousStep,
                    child: const Text('Back'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ UPDATED: Clean progress bar with step counter
            Column(
              children: [
                // Step counter row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Current step
                    Text(
                      '${_currentStep + 1}/3',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    // Total steps
                    Text(
                      '3/3',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Step-based progress bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentStep >= 0 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentStep >= 1 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentStep >= 2 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(3),
                            bottomRight: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildProgramSelectionStep(communityId),
                  _buildUserSelectionStep(),
                  _buildContributionDetailsStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... Rest of the code remains the same (remove the _buildStepLabel method)
  Widget _buildProgramSelectionStep(String communityId) {
    return FutureBuilder<List<ProgramModel>>(
      future: _programService.getActiveProgramsByCommunity(communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final programs = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Program',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which program this contribution is for',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: programs.length,
                itemBuilder: (context, index) {
                  final program = programs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.event,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(program.title),
                      subtitle: Text(
                        '${program.programDate.day}/${program.programDate.month}/${program.programDate.year}',
                      ),
                      trailing: _selectedProgram?.programId == program.programId
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedProgram = program;
                        });
                        _goToNextStep();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserSelectionStep() {
    final auth = Provider.of<AppAuthProvider>(context);
    final communityId = auth.user?.communityId ?? '';

    return FutureBuilder<List<UserModel>>(
      future: _userService.getUsersByCommunity(communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final users = snapshot.data ?? [];
        final filteredUsers = users.where((user) => user.isApproved).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Member',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which member made this contribution',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Text(
                          user.displayName?.isNotEmpty == true 
                              ? user.displayName![0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(user.displayName ?? 'Unknown User'),
                      subtitle: Text(user.email),
                      trailing: _selectedUser?.uid == user.uid
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedUser = user;
                        });
                        _goToNextStep();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContributionDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contribution Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter contribution amount and payment method',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),

        // Amount input
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              _amount = double.tryParse(value) ?? 0;
            });
          },
        ),
        const SizedBox(height: 16),

        // Payment method dropdown
        DropdownButtonFormField<String>(
          value: _paymentMethod,
          decoration: InputDecoration(
            labelText: 'Payment Method',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: _paymentMethods.map((method) {
            return DropdownMenuItem(
              value: method,
              child: Text(method[0].toUpperCase() + method.substring(1)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _paymentMethod = value!;
            });
          },
        ),
        const SizedBox(height: 20),

        // Summary
        if (_selectedProgram != null && _selectedUser != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Program: ${_selectedProgram!.title}'),
                  Text('Member: ${_selectedUser!.displayName}'),
                  Text('Amount: ₹$_amount'),
                  Text('Payment: ${_paymentMethod[0].toUpperCase() + _paymentMethod.substring(1)}'),
                ],
              ),
            ),
          ),

        const Spacer(),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _amount > 0 ? _submitContribution : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Add Contribution'),
          ),
        ),
      ],
    );
  }

  void _goToNextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _submitContribution() async {
    if (_selectedProgram == null || _selectedUser == null || _amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final contribution = ContributionModel(
        contributionId: '', // Will be set by Firestore
        programId: _selectedProgram!.programId,
        userId: _selectedUser!.uid,
        communityId: _selectedProgram!.communityId,
        amount: _amount,
        paymentMethod: _paymentMethod,
      );

      await _contributionService.addContribution(contribution);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution added successfully!')),
      );

      Navigator.pop(context); // Close modal
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding contribution: $e')),
      );
    }
  }
}