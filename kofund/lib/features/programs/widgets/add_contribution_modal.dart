// lib/features/history/widgets/add_contribution_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/services/program_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../../features/contributions/models/contribution_model.dart';
import '../../../features/programs/models/program_model.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/contributions/providers/contribution_provider.dart'; // Add this
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
class AddContributionModal extends StatefulWidget {
  final String? preSelectedProgramId;
  final String? preSelectedProgramName;
  final bool isMonthlyProgram;

  const AddContributionModal({
    super.key,
    this.preSelectedProgramId,
    this.preSelectedProgramName,
    this.isMonthlyProgram = false,
  });

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
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // Cache users future to avoid reloading on each setState
  Future<List<UserModel>>? _usersFuture;
  String? _lastCommunityId;
  // Amount controller to allow programmatic updates (auto-fill)
  late TextEditingController _amountController;
  final FocusNode _amountFocusNode = FocusNode();
  bool _hasAutofocusedAmount = false;
  bool _isSubmitting = false; // Add this guard
// Add these to your _AddContributionModalState class variables
int _currentDisplayYear = DateTime.now().year;
final bool _showMonthSelector = true; // Set to true to show by default for monthly programs

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
  _amountController = TextEditingController();
  
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

@override
void dispose() {
  _searchController.dispose();
  _amountController.dispose();
  _amountFocusNode.dispose();
  super.dispose();
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
      debugPrint('Error loading pre-selected program: $e');
    }
  }

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
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Header with premium typography
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface(context),
                ),
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text(
                'Add Contribution',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (_currentStep > 0)
                TextButton.icon(
                  onPressed: _goToPreviousStep,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Modern Pill Progress Indicator
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = _displayCurrentStep > index;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == _totalSteps - 1 ? 0 : 8),
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? AppColors.primary(context)
                        : AppColors.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Step $_displayCurrentStep of $_totalSteps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 20),

         Expanded(
  child: Column(
    children: [
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
      _buildBottomActionSection(),
    ],
  ),
),

          
        ],
      ),
    ),
  );
}
/// 🔒 Fixed Bottom Action Section (Modal-safe)
Widget _buildBottomActionSection() {
  if (_currentStep != 2) return const SizedBox.shrink();

  return SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(color: AppColors.border(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: FutureBuilder<bool>(
        future: NetworkService().isConnected,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final initialOnline = snapshot.data ?? true;

          return StreamBuilder<bool>(
            stream: NetworkService().onConnectionChanged,
            initialData: initialOnline,
            builder: (context, streamSnapshot) {
              final isOnline = streamSnapshot.data ?? initialOnline;
              final isDisabled = _amount <= 0 || !isOnline || isLoading || _isSubmitting;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isDisabled ? null : _submitContribution,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnline
                            ? AppColors.primary(context)
                            : Colors.grey[600],
                        disabledBackgroundColor:
                            Colors.grey.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting 
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isOnline
                                    ? (_isMonthlyProgram
                                        ? Icons.calendar_month
                                        : Icons.add)
                                    : Icons.wifi_off,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isOnline
                                    ? (_isMonthlyProgram
                                        ? 'Add Monthly Contribution'
                                        : 'Add Contribution')
                                    : 'Offline',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),

                  if (!isOnline)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Internet connection required',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
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
                  
                  final isSelected = _selectedProgram?.programId == program.programId;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary(context) 
                            : AppColors.border(context),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Program Icon Bubble
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isMonthly 
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : AppColors.primary(context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                              ),
                              child: Icon(
                                isMonthly ? Icons.calendar_today_rounded : Icons.event_rounded,
                                color: isMonthly ? Colors.green : AppColors.primary(context),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Program Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          program.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isMonthly)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                          ),
                                          child: Text(
                                            'Monthly',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    program.programDate != null
                                        ? '${program.programDate!.day}/${program.programDate!.month}/${program.programDate!.year}'
                                        : 'Monthly Program',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                  if (program.suggestedContribution != null && program.suggestedContribution! > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Suggested: ₹${program.suggestedContribution}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Selection Indicator
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(left: 16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary(context),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                      ? Colors.green.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
    // Cache the future so typing in the search field doesn't re-trigger the network call
    if (_usersFuture == null || _lastCommunityId != communityId) {
      _lastCommunityId = communityId;
      _usersFuture = _userService.getUsersByCommunity(communityId);
    }

    return FutureBuilder<List<UserModel>>(
      future: _usersFuture,
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
        var filteredUsers = users.where((user) => user.isApproved).toList();
        if (_searchQuery.isNotEmpty) {
          filteredUsers = filteredUsers.where((user) {
            final name = (user.displayName ?? '').toLowerCase();
            final email = user.email.toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        return Column(
          children: [
            // Modern Search bar
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.surface(context) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                border: Border.all(
                  color: AppColors.border(context),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                  letterSpacing: 0.3,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: 'Search members...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary(context), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary(context)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final isSelected = _selectedUser?.uid == user.uid;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary(context) 
                            : AppColors.border(context),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected 
                          ? [
                              BoxShadow(
                                color: AppColors.primary(context).withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      onTap: () {
                        setState(() {
                          _selectedUser = user;
                        });
                        _goToNextStep();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary(context).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  user.displayName?.isNotEmpty == true 
                                      ? user.displayName![0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: AppColors.primary(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName ?? 'Unknown User',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(left: 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary(context),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
  // auto-fill handled via controller when program is selected

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

        // Amount Input (Large and Centered)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          ),
          child: Column(
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: '0',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _amount = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_selectedProgram?.suggestedContribution != null && _selectedProgram!.suggestedContribution! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    child: Text(
                      'Suggested: ₹${_selectedProgram!.suggestedContribution}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_isMonthlyProgram && _availableMonths.isNotEmpty) 
          _buildMonthSelectorField(context),
          
        if (_isMonthlyProgram) const SizedBox(height: 24),

        // Payment Method Selection (Chips)
        Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _paymentMethods.map((method) {
            final isSelected = _paymentMethod == method;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: method == _paymentMethods.last ? 0 : 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _paymentMethod = method;
                    });
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary(context).withValues(alpha: 0.1)
                          : AppColors.surface(context),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary(context)
                            : AppColors.border(context),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          method.toLowerCase() == 'cash' 
                              ? Icons.payments_outlined
                              : Icons.account_balance_wallet_outlined,
                          color: isSelected 
                              ? AppColors.primary(context) 
                              : AppColors.textSecondary(context),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          method[0].toUpperCase() + method.substring(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected 
                                ? AppColors.primary(context) 
                                : AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        
        if (_isMonthlyProgram) const SizedBox(height: 16),
        const SizedBox(height: 20),

        // Summary
        if (_selectedProgram != null && _selectedUser != null)
Card(
  elevation: 0,
  color: AppColors.card(context),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
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
Widget _buildMonthSelectorField(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Contribution Month',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: () => _showMonthPickerModal(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary(context),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedMonth != null 
                      ? _formatMonthDisplay(_selectedMonth!)
                      : 'Select Month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

void _showMonthPickerModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Month',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Year Selection
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, color: AppColors.primary(context)),
                            onPressed: () {
                              setModalState(() {
                                _currentDisplayYear--;
                              });
                              setState(() {}); // Keep parent synced
                            },
                          ),
                          Text(
                            '$_currentDisplayYear',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, color: AppColors.primary(context)),
                            onPressed: () {
                              setModalState(() {
                                _currentDisplayYear++;
                              });
                              setState(() {}); // Keep parent synced
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Month Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNumber = index + 1;
                      final monthId = '$_currentDisplayYear-${monthNumber.toString().padLeft(2, '0')}';
                      final isSelected = monthId == _selectedMonth;
                      final isCurrentMonth = monthId == _formatMonthId(DateTime.now());
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMonth = monthId;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.primary(context) 
                                : isCurrentMonth
                                    ? AppColors.primary(context).withValues(alpha: 0.1)
                                    : AppColors.surface(context),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                            border: Border.all(
                              color: isSelected 
                                  ? AppColors.primary(context) 
                                  : isCurrentMonth
                                      ? AppColors.primary(context)
                                      : AppColors.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getShortMonthName(monthNumber),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSelected 
                                    ? Colors.white 
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
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
            color: AppColors.primary(context).withValues(alpha: 0.12),
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
      if (_currentStep == 2 && !_hasAutofocusedAmount) {
        _hasAutofocusedAmount = true;
        // Delay focus request to ensure the step is rendered
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _amountFocusNode.requestFocus();
          }
        });
      }
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
  if (_isSubmitting) return; // Guard against multiple clicks

  // Validate required fields
  if (_selectedProgram == null || _selectedUser == null || _amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill all required fields'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Validate month selection for monthly programs
  if (_isMonthlyProgram && (_selectedMonth == null || _selectedMonth!.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select month for monthly contribution'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    setState(() => _isSubmitting = true); // Start submission
    
    // Get current user info for entry tracking
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = auth.user;

    final contribution = ContributionModel(
      contributionId: '', // Will be set by Firestore
      programId: _selectedProgram!.programId,
      userId: _selectedUser!.uid, // Who contributed
      contributorName: _selectedUser!.displayName ?? 'Unknown',
      communityId: _selectedProgram!.communityId,
      amount: _amount,
      paymentMethod: _paymentMethod,
      addedByUserId: currentUser?.uid,
      addedByUserName: currentUser?.displayName ?? 'Admin',
      addedAt: Timestamp.now(),
      isMonthlyContribution: _isMonthlyProgram,
      monthId: _isMonthlyProgram ? _selectedMonth : null,
      createdAt: Timestamp.now(),
    );

    // Use Provider to add contribution
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    await contributionProvider.addContribution(contribution);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Contribution added successfully!'),
        backgroundColor: AppColors.primary(context),
      ),
    );

    if (mounted) Navigator.pop(context); // Close modal
  } catch (e) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error adding contribution: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
}

