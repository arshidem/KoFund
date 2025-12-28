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
import '../../../features/contributions/providers/contribution_provider.dart'; // Add this
import '../../../core/constants/app_colors.dart';
class AddContributionModal extends StatefulWidget {
  final String? preSelectedProgramId;
  final String? preSelectedProgramName;
  final bool isMonthlyProgram;

  const AddContributionModal({
    Key? key,
    this.preSelectedProgramId,
    this.preSelectedProgramName,
    this.isMonthlyProgram = false,
  }) : super(key: key);

  @override
  State<AddContributionModal> createState() => _AddContributionModalState();
}

class _AddContributionModalState extends State<AddContributionModal> {
  final _contributionService = ContributionService();
  final _programService = ProgramService();
  final _userService = UserService();
  
  int _currentStep = 0;
  int get _totalSteps {
  return widget.preSelectedProgramId != null ? 2 : 3;
}

int get _displayCurrentStep {
  return widget.preSelectedProgramId != null ? _currentStep : _currentStep + 1;
}
  ProgramModel? _selectedProgram;
  UserModel? _selectedUser;
  double _amount = 0;
  String _paymentMethod = 'cash';
  final List<String> _paymentMethods = ['cash', 'upi'];
  bool _hasSkippedInitialStep = false;
  bool _isMonthlyProgram = false;
  String? _selectedMonth;
  List<String> _availableMonths = [];
// Add these to your _AddContributionModalState class variables
int _currentDisplayYear = DateTime.now().year;
bool _showMonthSelector = true; // Set to true to show by default for monthly programs

// Helper methods for month handling
String _formatMonthId(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String _formatMonthDisplay(String monthId) {
  final parts = monthId.split('-');
  if (parts.length != 2) return monthId;
  
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  
  final date = DateTime(year, month, 1);
  return DateFormat('MMMM yyyy').format(date);
}

String _getShortMonthName(int monthNumber) {
  switch (monthNumber) {
    case 1: return 'Jan';
    case 2: return 'Feb';
    case 3: return 'Mar';
    case 4: return 'Apr';
    case 5: return 'May';
    case 6: return 'Jun';
    case 7: return 'Jul';
    case 8: return 'Aug';
    case 9: return 'Sep';
    case 10: return 'Oct';
    case 11: return 'Nov';
    case 12: return 'Dec';
    default: return '???';
  }
}

void _initializeMonths() {
  final months = <String>{};
  final now = DateTime.now();
  
  // ✅ Generate months for ALL years we might need
  // Start from 2 years ago
  for (int i = -2; i <= 2; i++) {
    final year = now.year + i;
    for (int month = 1; month <= 12; month++) {
      final date = DateTime(year, month, 1);
      months.add(_formatMonthId(date));
    }
  }
  
  final sortedMonths = months.toList();
  sortedMonths.sort(); // Sort ascending
  setState(() {
    _availableMonths = sortedMonths;
    _selectedMonth = _formatMonthId(DateTime.now()); // Default to current month
    _currentDisplayYear = now.year; // Start with current year
  });
}

// ✅ Helper method to get months for the currently displayed year
List<String> _getMonthsForYear(int year) {
  return [
    '$year-01', '$year-02', '$year-03', '$year-04',
    '$year-05', '$year-06', '$year-07', '$year-08',
    '$year-09', '$year-10', '$year-11', '$year-12',
  ];
}

void _goToPreviousYear() {
  setState(() {
    _currentDisplayYear--;
  });
}

void _goToNextYear() {
  setState(() {
    _currentDisplayYear++;
  });
}

@override
void initState() {
  super.initState();
  
  // If program is pre-selected, mark that we need to skip initial step
  if (widget.preSelectedProgramId != null) {
    _isMonthlyProgram = widget.isMonthlyProgram;
    
    // Load the pre-selected program
    if (widget.preSelectedProgramId != null) {
      _loadPreSelectedProgram();
    }
    
    // Initialize months if monthly program
    if (_isMonthlyProgram) {
      _initializeMonths();
    }
  }
}


  Future<void> _loadPreSelectedProgram() async {
    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      final communityId = auth.user?.communityId ?? '';
      
      final programs = await _programService.getActiveProgramsByCommunity(communityId);
final program = programs.firstWhere(
  (p) => p.programId == widget.preSelectedProgramId,
  orElse: () => ProgramModel(
    programId: widget.preSelectedProgramId!,
    communityId: communityId,
    title: widget.preSelectedProgramName ?? 'Unknown Program',
    description: '',
    programDate: DateTime.now(),
    location: '',
    maxParticipants: 0,
    participantType: 'fixed',
    status: 'active',
    createdBy: '',
    createdAt: Timestamp.now(),
    programType: 'general',
    isMonthlyPaymentProgram: widget.isMonthlyProgram,
    // Don't include estimatedTotalAmount parameter
  ),
);
      
      setState(() {
        _selectedProgram = program;
        _isMonthlyProgram = program.isMonthlyPaymentProgram;
        
        if (_isMonthlyProgram) {
          _availableMonths = _generateMonthOptions();
          _selectedMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
        }
      });
    } catch (e) {
      print('Error loading pre-selected program: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final communityId = auth.user?.communityId ?? '';
return Scaffold(
  backgroundColor: Colors.transparent,

  bottomNavigationBar: _currentStep == 2
      ? SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border(
                top: BorderSide(color: AppColors.border(context)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _amount > 0 ? _submitContribution : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMonthlyProgram
                      ? AppColors.primary(context)
                      : AppColors.primary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _isMonthlyProgram
                      ? 'Add Monthly Contribution'
                      : 'Add Contribution',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        )
      : null,

      body: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 30),
            
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

            // Progress bar
      Column(
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_displayCurrentStep}/$_totalSteps', // Use dynamic step count
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          '$_totalSteps/$_totalSteps', // Use dynamic step count
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    Row(
      children: List.generate(_totalSteps, (index) {
        return Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: _displayCurrentStep > index 
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[200],
              borderRadius: index == 0 
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      bottomLeft: Radius.circular(3),
                    )
                  : index == _totalSteps - 1
                      ? const BorderRadius.only(
                          topRight: Radius.circular(3),
                          bottomRight: Radius.circular(3),
                        )
                      : BorderRadius.zero,
            ),
          ),
        );
      }),
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
Widget _buildLoadingState() {
  return const Center(
    child: CircularProgressIndicator(),
  );
}
Widget _buildProgramSelectionStep(String communityId) {
  // Only skip if program is pre-selected AND we haven't skipped yet
  if (widget.preSelectedProgramId != null && !_hasSkippedInitialStep) {
    // This is the initial load, skip to user selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentStep = 1; // Skip to user selection
          _hasSkippedInitialStep = true; // Mark that we've skipped
        });
      }
    });
    return _buildLoadingState();
  }

  // Show actual program selection
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

    // Show program info if pre-selected
    if (widget.preSelectedProgramId != null && _selectedProgram != null) {
      return Column(
        children: [
          // Program info card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isMonthlyProgram 
                      ? Colors.green.withOpacity(0.1)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isMonthlyProgram ? Icons.calendar_month : Icons.event,
                  color: _isMonthlyProgram ? Colors.green : Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Row(
                children: [
                  Text(_selectedProgram!.title),
                  if (_isMonthlyProgram) ...[
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
        
         
            ),
          ),
          
          Expanded(
            child: _buildUserList(communityId),
          ),
        ],
      );
    }

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

        Expanded(
          child: _buildUserList(communityId),
        ),
      ],
    );
  }

  Widget _buildUserList(String communityId) {
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
          children: [
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
  // Auto-fill amount with suggested contribution
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

        // ✅ ADD: Month selector for monthly programs (ALWAYS SHOW IF MONTHLY PROGRAM)
        if (_isMonthlyProgram && _availableMonths.isNotEmpty) ...[
          _buildMonthGridSelector(context),
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
  elevation: 0,
  color: AppColors.card(context),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: AppColors.border(context)),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary(context),
          ),
        ),
        const SizedBox(height: 16),

        // Grid content
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisSpacing: 8,
            crossAxisSpacing: 12,
            childAspectRatio: 5.0,
          ),
          children: [
            _buildSummaryItem(
              context,
              label: 'Program',
              value: _selectedProgram!.title,
              icon: Icons.folder_open,
            ),
            if (_isMonthlyProgram)
              _buildSummaryItem(
                context,
                label: 'Type',
                value: 'Monthly Contribution',
                icon: Icons.calendar_month,
              ),
            _buildSummaryItem(
              context,
              label: 'Member',
              value: _selectedUser?.displayName ?? 'Unknown Member',
              icon: Icons.person_outline,
            ),
            _buildSummaryItem(
              context,
              label: 'Amount',
              value: '₹$_amount',
              icon: Icons.payments,
              valueColor: AppColors.success(context),
            ),
            _buildSummaryItem(
              context,
              label: 'Payment',
              value:
                  _paymentMethod[0].toUpperCase() + _paymentMethod.substring(1),
              icon: Icons.account_balance_wallet,
            ),
            if (_isMonthlyProgram && _selectedMonth != null)
              _buildSummaryItem(
                context,
                label: 'Month',
                value: _formatMonthDisplay(_selectedMonth!),
                icon: Icons.event,
              ),
          ],
        ),
      ],
    ),
  ),
),


  
      ],
    ),
  );
}
Widget _buildSummaryItem(
  BuildContext context, {
  required String label,
  required String value,
  required IconData icon,
  Color? valueColor,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary(context).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.primary(context),
          ),
        ),
        const SizedBox(width: 10),

        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMonthGridSelector(BuildContext context) {
  return Card(
    color: Theme.of(context).cardColor,
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Month',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    onPressed: _goToPreviousYear,
                    tooltip: 'Previous year',
                  ),
                  Text(
                    '$_currentDisplayYear',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    onPressed: _goToNextYear,
                    tooltip: 'Next year',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthNumber = index + 1;
              final monthId = '$_currentDisplayYear-${monthNumber.toString().padLeft(2, '0')}';
              final isSelected = monthId == _selectedMonth;
              final isCurrentMonth = monthId == _formatMonthId(DateTime.now());
              
              // ✅ Check if month is in our available months list
              final isAvailable = _availableMonths.contains(monthId);
              
              // If not available, add it to the list dynamically
              if (!isAvailable && !_availableMonths.any((m) => m.startsWith('$_currentDisplayYear'))) {
                // This is a new year we haven't loaded yet
                // Dynamically add months for this year
                final newMonths = _getMonthsForYear(_currentDisplayYear);
                _availableMonths.addAll(newMonths);
                _availableMonths.sort();
              }
              
              // Calculate if it's a future month
              final now = DateTime.now();
              final currentMonthId = _formatMonthId(now);
              final isFutureMonth = monthId.compareTo(currentMonthId) > 0;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMonth = monthId;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : isFutureMonth 
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary 
                          : isCurrentMonth 
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected 
                        ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                        _getShortMonthName(monthNumber),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected 
                              ? Colors.white 
                              : isFutureMonth 
                                ? Theme.of(context).disabledColor
                                : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      
                      const SizedBox(height: 2),
                      
                      Text(
                        _currentDisplayYear.toString().substring(2), // Show last 2 digits
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected 
                              ? Colors.white.withOpacity(0.9)
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                      
                      if (isCurrentMonth && !isSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Selected month info
          if (_selectedMonth != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Selected: ${_formatMonthDisplay(_selectedMonth!)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
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

  String _getMonthDisplayName(String monthId) {
    final parts = monthId.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);
    
    final monthName = DateFormat('MMM').format(date);
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
    if (_currentStep == 2) {
      // From month selector step (step 2) → go back to member list (step 1)
      setState(() {
        _currentStep = 1;
      });
    } else {
      // From any other step (step 1 or 0) → close modal
      Navigator.pop(context);
    }
  } else {
    Navigator.pop(context);
  }
}

Future<void> _submitContribution() async {
  if (_selectedProgram == null || _selectedUser == null || _amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please fill all required fields'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Validate month selection for monthly programs
  if (_isMonthlyProgram && (_selectedMonth == null || _selectedMonth!.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please select month for monthly contribution'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    // Get current user info for entry tracking
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = auth.user;

    final contribution = ContributionModel(
      contributionId: '', // Will be set by Firestore
      programId: _selectedProgram!.programId,
      userId: _selectedUser!.uid, // Who contributed
      communityId: _selectedProgram!.communityId,
      amount: _amount,
      paymentMethod: _paymentMethod,
      
      // ✅ ADD: Entry tracking - who added this record
      addedByUserId: currentUser?.uid,
      addedByUserName: currentUser?.displayName ?? 'Admin',
      addedAt: Timestamp.now(),
      
      // ✅ Monthly fields
      isMonthlyContribution: _isMonthlyProgram,
      monthId: _isMonthlyProgram ? _selectedMonth : null,
      
      // Existing timestamp field
      createdAt: Timestamp.now(),
    );

    // Use Provider to add contribution
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    await contributionProvider.addContribution(contribution);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contribution added successfully!'),
        backgroundColor: AppColors.primary(context),
      ),
    );

    Navigator.pop(context); // Close modal
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error adding contribution: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}