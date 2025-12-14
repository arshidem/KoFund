// lib/features/history/widgets/add_contribution_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
  
  // ✅ ADD: Monthly contribution fields
  bool _isMonthlyProgram = false;
  String? _selectedMonth; // Format: "2025-01"
  List<String> _availableMonths = [];

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
                  final isMonthly = program.isMonthlyPaymentProgram;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMonthly 
                              ? Colors.green.withOpacity(0.1)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isMonthly ? Icons.calendar_month : Icons.event,
                          color: isMonthly ? Colors.green : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(program.title),
                          if (isMonthly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Monthly',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${program.programDate.day}/${program.programDate.month}/${program.programDate.year}',
                          ),
                          if (program.suggestedContribution != null && program.suggestedContribution! > 0)
                            Text(
                              'Suggested: ₹${program.suggestedContribution}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                        ],
                      ),
                      trailing: _selectedProgram?.programId == program.programId
                          ? Icon(
                              Icons.check_circle, 
                              color: isMonthly ? Colors.green : Theme.of(context).colorScheme.primary
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedProgram = program;
                          _isMonthlyProgram = program.isMonthlyPaymentProgram;
                          
                          // ✅ Generate month options if monthly program
                          if (_isMonthlyProgram) {
                            _availableMonths = _generateMonthOptions();
                            _selectedMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
                          } else {
                            _availableMonths = [];
                            _selectedMonth = null;
                          }
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
    // ✅ Auto-fill amount with suggested contribution
    if (_amount == 0 && _selectedProgram != null && _selectedProgram!.suggestedContribution != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _amount = _selectedProgram!.suggestedContribution!;
        });
      });
    }

    return SingleChildScrollView(
      child: Column(
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

          // ✅ ADD: Month selector for monthly programs
          if (_isMonthlyProgram && _availableMonths.isNotEmpty) ...[
            _buildMonthGridSelector(), // ✅ FIXED: Changed from _buildMonthSelector()
            const SizedBox(height: 16),
          ],

          // Amount input
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixText: _selectedProgram?.suggestedContribution != null 
                  ? 'Suggested: ₹${_selectedProgram!.suggestedContribution}'
                  : null,
            ),
            keyboardType: TextInputType.number,
            initialValue: _amount > 0 ? _amount.toString() : null,
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
                    if (_isMonthlyProgram) 
                      Text('Type: Monthly Program Contribution'),
                    Text('Member: ${_selectedUser!.displayName}'),
                    Text('Amount: ₹$_amount'),
                    Text('Payment: ${_paymentMethod[0].toUpperCase() + _paymentMethod.substring(1)}'),
                    if (_isMonthlyProgram && _selectedMonth != null)
                      Text('Month: ${_getMonthDisplayName(_selectedMonth!)}'),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _amount > 0 ? _submitContribution : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isMonthlyProgram ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                _isMonthlyProgram ? 'Add Monthly Contribution' : 'Add Contribution',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

Widget _buildMonthGridSelector() {
  // Find index of current month
  final currentMonthIndex = _availableMonths.indexWhere(
    (month) => month == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}",
  );

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
      
      SizedBox(
        height: 80,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate position to scroll to
            final double itemWidth = 70; // Width of each month card
            final double spacing = 12; // Right padding
            final double centerOffset = (constraints.maxWidth / 2) - (itemWidth / 2);
            
            return Scrollable(
              axisDirection: AxisDirection.right,
              controller: ScrollController(),
              viewportBuilder: (context, offset) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Auto-scroll to current month after build
                  if (currentMonthIndex != -1) {
                    final double targetOffset = 
                        (currentMonthIndex * (itemWidth + spacing)) - centerOffset;
                    
                    // Use a scroll controller to programmatically scroll
                    Scrollable.ensureVisible(
                      context,
                      alignment: 0.5, // Center alignment
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                });
                
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  controller: ScrollController(
                    initialScrollOffset: currentMonthIndex != -1 
                        ? (currentMonthIndex * (itemWidth + spacing)) - centerOffset
                        : 0,
                  ),
                  itemCount: _availableMonths.length,
                  itemBuilder: (context, index) {
                    final month = _availableMonths[index];
                    final isSelected = _selectedMonth == month;
                    final isCurrentMonth = month == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
                    
                    return Padding(
                      padding: EdgeInsets.only(
                        right: 12,
                        left: index == 0 ? 12 : 0, // Add left padding for first item
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMonth = month),
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.blue 
                                : (isCurrentMonth ? Colors.blue[50] : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.blue : (Colors.grey[300] ?? Colors.grey),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected 
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getMonthAbbreviation(month),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                _getYear(month),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                ),
                              ),
                              if (isCurrentMonth)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.blue[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Current',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isSelected ? Colors.blue : Colors.blue[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      
      // Selected month info
      if (_selectedMonth != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Selected: ${_getMonthDisplayName(_selectedMonth!)}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      
      // Scroll hint
      if (_availableMonths.length > 5)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_left, size: 16, color: Colors.grey[500]),
              Text(
                ' Scroll for more months ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Icon(Icons.arrow_right, size: 16, color: Colors.grey[500]),
            ],
          ),
        ),
    ],
  );
}

String _getMonthAbbreviation(String monthId) {
  final parts = monthId.split('-');
  final month = int.parse(parts[1]);
  return DateFormat('MMM').format(DateTime(0, month));
}

String _getYear(String monthId) {
  final parts = monthId.split('-');
  return parts[0];
}

List<String> _generateMonthOptions() {
  final List<String> months = [];
  final now = DateTime.now();
  
  // Generate 6 months before current, current month, and 6 months after
  for (int i = -6; i <= 6; i++) {
    final date = DateTime(now.year, now.month + i, 1);
    final monthStr = "${date.year}-${date.month.toString().padLeft(2, '0')}";
    months.add(monthStr);
  }
  
  return months;
}

  // ✅ ADD: Get month display name
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
    
    // ✅ ADD: Validate month selection for monthly programs
    if (_isMonthlyProgram && (_selectedMonth == null || _selectedMonth!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select month for monthly contribution')),
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
        // ✅ ADD: Monthly fields
        isMonthlyContribution: _isMonthlyProgram,
        monthId: _isMonthlyProgram ? _selectedMonth : null,
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