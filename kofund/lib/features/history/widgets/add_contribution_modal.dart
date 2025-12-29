// lib/features/history/widgets/add_contribution_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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
  final List<String> _paymentMethods = ['cash', 'upi'];
  String _memberSearchQuery = '';
  List<UserModel> _filteredUsers = [];
  List<UserModel> _allUsers = [];
  
  // Program search
  String _programSearchQuery = '';
  List<ProgramModel> _filteredPrograms = [];
  List<ProgramModel> _allPrograms = [];
  bool _isMonthlyProgram = false;
  String? _selectedMonth;
  List<String> _availableMonths = [];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final communityId = auth.user?.communityId ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // AppBar-like header with gradient
Container(
  decoration: BoxDecoration(
    gradient: AppColors.primaryGradient(context),
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(20),
    ),
  ),
  child: Column(
    children: [
      // Main header row
      Padding(
        padding: const EdgeInsets.only(right: 16, left: 16, top: 40, bottom: 16),
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            
            // Spacer to push title to center
            Expanded(
              child: Center(
                child: Text(
                  'Add Contribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Right side button or empty container
            if (_currentStep > 0)
              TextButton(
                onPressed: _goToPreviousStep,
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              // Empty container to balance the left icon button
              SizedBox(
                width: 48, // Same width as IconButton
              ),
          ],
        ),
      ),

      // Step progress section
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentStep + 1}/3',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '3/3',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Step progress indicator
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 0 
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          bottomLeft: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 1 
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 2 
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Step labels (optional)
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Program',
                    style: TextStyle(
                      fontSize: 11,
                      color: _currentStep >= 0 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.5),
                      fontWeight: _currentStep >= 0 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 11,
                      color: _currentStep >= 1 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.5),
                      fontWeight: _currentStep >= 1 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11,
                      color: _currentStep >= 2 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.5),
                      fontWeight: _currentStep >= 2 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildProgramSelectionStep(communityId),
                    _buildUserSelectionStep(communityId),
                    _buildContributionDetailsStep(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildProgramSelectionStep(String communityId) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Select Program',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary(context),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Choose which program this contribution is for',
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 20),

      // Program search bar
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border(context),
            width: 1,
          ),
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _programSearchQuery = value.toLowerCase();
              if (_allPrograms.isNotEmpty) {
                _filteredPrograms = _allPrograms.where((program) {
                  return program.title.toLowerCase().contains(_programSearchQuery) ||
                         (program.suggestedContribution != null && 
                          program.suggestedContribution.toString().contains(_programSearchQuery)) ||
                         DateFormat('dd/MM/yyyy').format(program.programDate).contains(_programSearchQuery);
                }).toList();
              }
            });
          },
decoration: InputDecoration(
  hintText: 'Search programs...',
  hintStyle: TextStyle(
    color: AppColors.textTertiary(context),
    fontSize: 14,
  ),
  prefixIcon: Icon(
    Icons.search,
    color: AppColors.textSecondary(context),
    size: 20,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: AppColors.border(context),
      width: 1,
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: AppColors.border(context),
      width: 1,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: AppColors.primary(context),
      width: 1.5,
    ),
  ),
  filled: true,
  fillColor: AppColors.background(context),
  contentPadding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  ),
),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 14,
          ),
        ),
      ),
      const SizedBox(height: 16),

Expanded(
  child: FutureBuilder<List<ProgramModel>>(
    future: _programService.getActiveProgramsByCommunity(communityId),
    builder: (context, snapshot) {
     if (snapshot.connectionState == ConnectionState.waiting) {
  // Skeleton loader that matches exact program list layout
  return ListView.builder(
    itemCount: 5, // Show 5 skeleton items
    itemBuilder: (context, index) {
      final isLastItem = index == 4; // Since we have 5 items
      
      return Column(
        children: [
          // Skeleton program card (exact match to your layout)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: null, // Disabled during loading
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Skeleton icon (exact size 40x40)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary(context).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Skeleton text content (exact match)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and monthly chip skeleton
                          Row(
                            children: [
                              // Title skeleton (Flexible like actual layout)
                              Flexible(
                                child: Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppColors.textTertiary(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // Monthly chip skeleton (shows on some items)
                              if (index % 2 == 0) // 50% chance like real data
                                Container(
                                  width: 55,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.textTertiary(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Date and suggested amount skeleton
                          Container(
                            height: 15,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Skeleton selection indicator (exact size with padding)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary(context).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Horizontal divider skeleton (exact match to your divider)
          if (!isLastItem)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border(context).withOpacity(0.3),
              indent: 16,
              endIndent: 16,
            ),
        ],
      );
    },
  );
}

      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 44,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load programs',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // You can add retry logic here
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }

      final programs = snapshot.data ?? [];
      _allPrograms = programs;
      
      // Apply search filter if query exists
      final displayPrograms = _programSearchQuery.isEmpty 
          ? programs 
          : programs.where((program) {
              return program.title.toLowerCase().contains(_programSearchQuery) ||
                     (program.suggestedContribution != null && 
                      program.suggestedContribution.toString().contains(_programSearchQuery)) ||
                     DateFormat('dd/MM/yyyy').format(program.programDate).contains(_programSearchQuery);
            }).toList();

      if (displayPrograms.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _programSearchQuery.isEmpty ? Icons.event_busy : Icons.search_off,
                size: 44,
                color: AppColors.textTertiary(context),
              ),
              const SizedBox(height: 16),
              Text(
                _programSearchQuery.isEmpty 
                    ? 'No programs found' 
                    : 'No matching programs',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _programSearchQuery.isEmpty
                    ? 'Create a program in your community first'
                    : 'Try a different search term',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: displayPrograms.length,
        itemBuilder: (context, index) {
          final program = displayPrograms[index];
          final isMonthly = program.isMonthlyPaymentProgram;
          final isLastItem = index == displayPrograms.length - 1;
          
          return Column(
            children: [
              // Program card with left border divider style
              Material(
                color: Colors.transparent,
                child: InkWell(
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMonthly 
                                ? Colors.green.withOpacity(0.1)
                                : AppColors.primary(context).withOpacity(0.1),
                          ),
                          child: Icon(
                            isMonthly ? Icons.calendar_month : Icons.event,
                            size: 20,
                            color: isMonthly ? Colors.green : AppColors.primary(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Main content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and monthly chip in same line
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      program.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppColors.textPrimary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMonthly) 
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'Monthly',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('dd/MM/yyyy').format(program.programDate)} • Suggested: ₹${program.suggestedContribution?.toStringAsFixed(2) ?? '0.00'}',
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
                        
                        // Selection indicator
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _selectedProgram?.programId == program.programId
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(context),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                )
                              : Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.border(context),
                                      width: 2,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Horizontal divider (except last item)
              if (!isLastItem)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border(context),
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        },
      );
    },
  ),
),
    ],
  );
}

Widget _buildUserSelectionStep(String communityId) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Select Member',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary(context),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Choose which member made this contribution',
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 20),

      // Search bar
Container(
  margin: const EdgeInsets.only(bottom: 16),
  child: TextField(
    onChanged: (value) {
      setState(() {
        _memberSearchQuery = value.toLowerCase();
        if (_allUsers.isNotEmpty) {
          _filteredUsers = _allUsers.where((user) {
            return (user.displayName?.toLowerCase().contains(_memberSearchQuery) ?? false) ||
                   user.email.toLowerCase().contains(_memberSearchQuery) ||
                   (user.role?.toLowerCase().contains(_memberSearchQuery) ?? false);
          }).toList();
        }
      });
    },
    decoration: InputDecoration(
      hintText: 'Search members...',
      hintStyle: TextStyle(
        color: AppColors.textTertiary(context),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        Icons.search,
        color: AppColors.textSecondary(context),
        size: 20,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primary(context),
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: AppColors.background(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    ),
    style: TextStyle(
      color: AppColors.textPrimary(context),
      fontSize: 14,
    ),
  ),
),
      const SizedBox(height: 16),

   Expanded(
  child: FutureBuilder<List<UserModel>>(
    future: _userService.getUsersByCommunity(communityId),
    builder: (context, snapshot) {
   if (snapshot.connectionState == ConnectionState.waiting) {
  // Skeleton loader that matches actual user list layout
  return ListView.builder(
    itemCount: 5, // Show 5 skeleton items
    itemBuilder: (context, index) {
      final isLastItem = index == 4; // Since we have 5 items
      
      return Column(
        children: [
          // Skeleton member card
          Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Skeleton avatar (exact match)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary(context).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Skeleton text content (exact match)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name skeleton (exact font size and weight)
                        Container(
                          width: double.infinity,
                          height: 18,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        
                        // Email skeleton (exact font size)
                        Container(
                          width: double.infinity,
                          height: 15,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        
                        // Role skeleton (exact size and shape)
                        if (index % 2 == 0) // Show role skeleton for some items like actual data
                          Container(
                            width: 70,
                            height: 16,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Skeleton selection indicator (exact size)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary(context).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Horizontal divider skeleton (except last item)
          if (!isLastItem)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border(context).withOpacity(0.3),
              indent: 16,
              endIndent: 16,
            ),
        ],
      );
    },
  );
}

      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 44,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load members',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // You can add retry logic here
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }

      final users = snapshot.data ?? [];
      _allUsers = users;
      final approvedUsers = users.where((user) => user.isApproved).toList();
      
      // Apply search filter if query exists
      final displayUsers = _memberSearchQuery.isEmpty 
          ? approvedUsers 
          : approvedUsers.where((user) {
              return (user.displayName?.toLowerCase().contains(_memberSearchQuery) ?? false) ||
                     user.email.toLowerCase().contains(_memberSearchQuery) ||
                     (user.role?.toLowerCase().contains(_memberSearchQuery) ?? false);
            }).toList();

      if (displayUsers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _memberSearchQuery.isEmpty ? Icons.group_off : Icons.search_off,
                size: 44,
                color: AppColors.textTertiary(context),
              ),
              const SizedBox(height: 16),
              Text(
                _memberSearchQuery.isEmpty 
                    ? 'No approved members found' 
                    : 'No matching members',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _memberSearchQuery.isEmpty
                    ? 'Add members to your community first'
                    : 'Try a different search term',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: displayUsers.length,
        itemBuilder: (context, index) {
          final user = displayUsers[index];
          final isLastItem = index == displayUsers.length - 1;
          
          return Column(
            children: [
              // Member card
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedUser = user;
                    });
                    _goToNextStep();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          backgroundColor: AppColors.primary(context).withOpacity(0.1),
                          radius: 20,
                          child: Text(
                            user.displayName?.isNotEmpty == true 
                                ? user.displayName![0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Main content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? 'Unknown User',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // User role indicator
                              if (user.role != null && user.role!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(user.role!).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getRoleColor(user.role!).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    user.role!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _getRoleColor(user.role!),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Selection indicator
                        _selectedUser?.uid == user.uid
                            ? Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary(context),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              )
                            : Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.border(context),
                                    width: 2,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Horizontal divider (except last item)
              if (!isLastItem)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border(context),
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        },
      );
    },
  ),
),
    ],
  );
}

// Helper method to get color based on user role
Color _getRoleColor(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return Colors.red;
    case 'moderator':
      return Colors.orange;
    case 'treasurer':
      return Colors.green;
    case 'secretary':
      return Colors.purple;
    default:
      return AppColors.primary(context);
  }
}

 Widget _buildContributionDetailsStep() {
  if (_amount == 0 && _selectedProgram != null && _selectedProgram!.suggestedContribution != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _amount = _selectedProgram!.suggestedContribution!;
      });
    });
  }

  return Column(
    children: [
      // Scrollable content
      Expanded(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80), // Add bottom padding for fixed button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contribution Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter contribution amount and payment method',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),

                if (_isMonthlyProgram && _availableMonths.isNotEmpty) ...[
                  _buildMonthGridSelector(),
                  const SizedBox(height: 20),
                ],

                // Amount input
                Card(
                  color: AppColors.surface(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(
                            text: _amount > 0 ? _amount.toStringAsFixed(2) : '',
                          ),
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.border(context),
                              ),
                            ),
                            suffixText: _selectedProgram?.suggestedContribution != null 
                                ? 'Suggested: ₹${_selectedProgram!.suggestedContribution!.toStringAsFixed(2)}'
                                : null,
                            suffixStyle: TextStyle(
                              color: AppColors.primary(context),
                              fontSize: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              _amount = double.tryParse(value) ?? 0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Payment method
                Card(
                  color: AppColors.surface(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.border(context),
                              ),
                            ),
                          ),
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                          ),
                          dropdownColor: AppColors.surface(context),
                          items: _paymentMethods.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Text(
                                method[0].toUpperCase() + method.substring(1),
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Summary card
                if (_selectedProgram != null && _selectedUser != null)
                  Card(
                    color: AppColors.surface(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                color: AppColors.primary(context),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.border(context),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummaryItem('Program', _selectedProgram!.title),
                                if (_isMonthlyProgram)
                                  _buildSummaryItem('Type', 'Monthly Program'),
                                _buildSummaryItem('Member', _selectedUser!.displayName ?? 'Unknown'),
                                _buildSummaryItem('Amount', '₹$_amount'),
                                _buildSummaryItem('Payment', 
                                  _paymentMethod[0].toUpperCase() + _paymentMethod.substring(1)),
                                if (_isMonthlyProgram && _selectedMonth != null)
                                  _buildSummaryItem('Month', _getMonthDisplayName(_selectedMonth!)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),

      // Fixed bottom button
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background(context),
          border: Border(
            top: BorderSide(
              color: AppColors.border(context),
              width: 1,
            ),
          ),
        ),
        child: ElevatedButton(
          onPressed: _amount > 0 ? _submitContribution : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: AppColors.textTertiary(context),
          ),
          child: Text(
            _isMonthlyProgram ? 'Add Monthly Contribution' : 'Add Contribution',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8, right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary(context),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGridSelector() {
    final currentMonthIndex = _availableMonths.indexWhere(
      (month) => month == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}",
    );

    return Card(
      color: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Month *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              height: 80,
              child: Scrollable(
                axisDirection: AxisDirection.right,
                viewportBuilder: (context, offset) {
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: ScrollController(
                      initialScrollOffset: currentMonthIndex != -1 
                          ? (currentMonthIndex * 82) - 120
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
                          left: index == 0 ? 4 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMonth = month),
                          child: Container(
                            width: 70,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppColors.primary(context)
                                  : (isCurrentMonth ? AppColors.primary(context).withOpacity(0.1) : Colors.transparent),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                    ? AppColors.primary(context)
                                    : (isCurrentMonth ? AppColors.primary(context) : AppColors.border(context)),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getMonthAbbreviation(month),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? Colors.white
                                        : AppColors.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  _getYear(month),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected 
                                        ? Colors.white.withOpacity(0.9)
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                                if (isCurrentMonth)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? Colors.white
                                          : AppColors.primary(context).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: isSelected 
                                            ? AppColors.primary(context)
                                            : AppColors.primary(context),
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
              ),
            ),
            
            if (_selectedMonth != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Selected: ${_getMonthDisplayName(_selectedMonth!)}',
                        style: TextStyle(
                          color: AppColors.primary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
      setState(() {
        _currentStep--;
      });
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
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = auth.user;
    
    final contribution = ContributionModel(
      contributionId: '', // Will be set by Firestore
      programId: _selectedProgram!.programId,
      userId: _selectedUser!.uid,
      contributorName: _selectedUser!.displayName ?? 'Unknown',
      communityId: _selectedProgram!.communityId,
      amount: _amount,
      paymentMethod: _paymentMethod,
      
      // Monthly fields
      isMonthlyContribution: _isMonthlyProgram,
      monthId: _isMonthlyProgram ? _selectedMonth : null,
      
      // Entry tracking
      addedByUserId: currentUser?.uid,
      addedByUserName: currentUser?.displayName ?? 'Unknown',
      addedAt: Timestamp.now(),
      
      // Edit tracking (defaults to false/nulls)
      isEdited: false,
      lastEditedByUserId: null,
      lastEditedByUserName: null,
      lastEditedAt: null,
      editReason: null,
      
      // Edit history
      editHistory: [],
      
      // Created at (will use default Timestamp.now() if not provided)
    );

    await _contributionService.addContribution(contribution);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contribution added successfully!'),
        backgroundColor: AppColors.primary(context),
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


}