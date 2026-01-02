// ✅ FIXED: Stats logic and auto-close month selector
// ✅ ADDED: Skeleton shimmer effect for loading state
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math'; // Add this import
import '../../models/program_model.dart';
import '../../providers/program_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/features/members/screens/member_details_screen.dart';
import 'package:kofund/features/programs/screens/add_participant_screen.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/app_auth_provider.dart';

// Add this at the top of your file or in a separate file
class SafeAsyncOperation {
  static Future<T?> execute<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required void Function() onDisposed,
  }) async {
    if (!context.mounted) {
      onDisposed();
      return null;
    }
    
    try {
      return await operation();
    } catch (e) {
      if (context.mounted) {
        rethrow;
      } else {
        onDisposed();
        return null;
      }
    }
  }
}
class ProgramParticipantsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramParticipantsTab({super.key, required this.program});

  @override
  State<ProgramParticipantsTab> createState() => _ProgramParticipantsTabState();
}

class _ProgramParticipantsTabState extends State<ProgramParticipantsTab> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _updatingParticipants = {};
  String _searchQuery = '';
  String _filterStatus = 'all';
  
  String? _selectedMonth;
  List<String> _availableMonths = [];
  bool _isLoadingMonths = false;
  Map<String, int> _monthPaymentCounts = {};
  int _streamKey = 0;
  int _currentDisplayYear = DateTime.now().year;
  bool _showMonthSelector = false;
  
  List<ParticipantModel> _cachedParticipants = [];

  @override
  void initState() {
    super.initState();
    if (widget.program.isMonthlyPaymentProgram) {
      _initializeMonths();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeMonths() async {
    if (!mounted) return;
    setState(() => _isLoadingMonths = true);
    
    try {
      final programProvider = context.read<ProgramProvider>();
      final paymentCounts = await programProvider.getMonthlyPaymentCounts(widget.program.programId);
      final months = _generateAllMonths();
      
      if (mounted) {
        setState(() {
          _availableMonths = months;
          _monthPaymentCounts = paymentCounts;
          _selectedMonth = _formatMonthId(DateTime.now());
          _currentDisplayYear = DateTime.now().year;
          _streamKey++;
        });
      }
    } catch (e) {
      final months = _generateAllMonths();
      if (mounted) {
        setState(() {
          _availableMonths = months;
          _selectedMonth = _formatMonthId(DateTime.now());
          _currentDisplayYear = DateTime.now().year;
          _monthPaymentCounts = {};
          _streamKey++;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMonths = false);
      }
    }
  }

  List<String> _generateAllMonths() {
    final months = <String>{};
    final now = DateTime.now();
    final currentYear = now.year;
    
    for (int year = currentYear - 2; year <= currentYear + 2; year++) {
      for (int month = 1; month <= 12; month++) {
        final date = DateTime(year, month, 1);
        months.add(_formatMonthId(date));
      }
    }
    
    final sortedMonths = months.toList();
    sortedMonths.sort((a, b) => b.compareTo(a));
    return sortedMonths;
  }

  String _formatMonthId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _formatMonthDisplay(String monthId) {
    try {
      final parts = monthId.split('-');
      if (parts.length != 2) return monthId;
      
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      
      final date = DateTime(year, month, 1);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return monthId;
    }
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
@override
Widget build(BuildContext context) {
  final isAdmin = _isAdmin(context);

  return Stack(
    children: [
      ListView(
        children: [
          _buildParticipantsStats(context),

          if (widget.program.isMonthlyPaymentProgram)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildMonthSelectorHeader(context),
            ),

          if (_showMonthSelector && widget.program.isMonthlyPaymentProgram)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildMonthGridSelector(context),
            ),

          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
            child: _buildSearchFilterBar(context),
          ),

          _buildParticipantsListForScrollView(context),

          // Bottom padding so FAB never overlaps content
          const SizedBox(height: 88),
        ],
      ),

      // ✅ FAB layer (same pattern as your working file)
      Positioned(
        bottom: 16,
        right: 16,
        child: Visibility(
          visible: isAdmin,
          child: FloatingActionButton(
            onPressed: () => _navigateToAddParticipantScreen(context),
            backgroundColor: AppColors.primary(context),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    ],
  );
}
Future<void> _navigateToAddParticipantScreen(BuildContext context) async {
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => AddParticipantScreen(
        program: widget.program,
      ),
    ),
  );

  if (!mounted) return;

  if (result == true) {
    setState(() {
      _streamKey++;
    });
  }
}

// ✅ Add this method - Check if current user is admin
// Update your import

// Update your _isAdmin method:
bool _isAdmin(BuildContext context) {
  final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
  final currentUser = authProvider.user;
  
  print('🔧 _isAdmin called:');
  print('   - User from authProvider: ${currentUser?.uid}');
  print('   - User isAdmin: ${currentUser?.isAdmin}');
  
  if (currentUser == null) {
    print('   ❌ User is null - returning false');
    return false;
  }
  
  // 1. Program creator is always admin
  if (currentUser.uid == widget.program.createdBy) {
    print('   ✅ User is program creator - returning true');
    return true;
  }
  
  // 2. User with 'admin' role
  if (currentUser.role == 'admin') {
    print('   ✅ User has admin role - returning true');
    return true;
  }
  
  // 3. User with isAdmin flag and approved
  if (currentUser.isAdmin == true) {
    print('   ✅ User has isAdmin flag - returning true');
    return true;
  }
  
  print('   ❌ User is not admin - returning false');
  return false;
}


  // Shimmer skeleton widget
  Widget _buildShimmerSkeleton() {
    return Column(
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: _buildShimmerParticipantCard(),
        );
      }),
    );
  }

  // Individual shimmer card
  Widget _buildShimmerParticipantCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface(context),
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
        
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border(context),
        ),
      ],
    );
  }

Widget _buildShimmerStats() {
  final skeletonColor = AppColors.textCards(context).withOpacity(0.25);

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          blurRadius: 6,
          offset: const Offset(0, 2),
          color: Colors.black.withOpacity(0.06),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔒 RESERVED HEADER SPACE (invisible)
        const SizedBox(height: 28),

        /// AMOUNT
        Container(
          width: 170,
          height: 26,
          decoration: BoxDecoration(
            color: skeletonColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),

        const SizedBox(height: 2),

        /// 🔒 RESERVED "expected" TEXT SPACE
        const SizedBox(height: 11),

        const SizedBox(height: 8),

        /// PROGRESS BAR
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: skeletonColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),

        const SizedBox(height: 10),

        /// STATS CHIPS
        Row(
          children: [
            _buildShimmerChip(),
            const SizedBox(width: 8),
            _buildShimmerChip(),
          ],
        ),
      ],
    ),
  );
}


Widget _buildShimmerChip() {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(
        vertical: 6,   // ⬅ match real chip height
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(context).withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon placeholder
          Container(
            width: 16,   // ⬅ match Icons.check_circle size
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.surface(context).withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),

          // Text placeholders
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 12, // ⬅ label text size
                decoration: BoxDecoration(
                  color: AppColors.surface(context).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 18,
                height: 14, // ⬅ value text size
                decoration: BoxDecoration(
                  color: AppColors.surface(context).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


  // Participants list with shimmer
  Widget _buildParticipantsListForScrollView(BuildContext context) {
    return StreamBuilder<List<ParticipantModel>>(
      key: ValueKey('participants-${widget.program.programId}-${_selectedMonth ?? 'regular'}-$_streamKey'),
      stream: _getParticipantsStream(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedParticipants.isEmpty) {
          return _buildShimmerSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    color: AppColors.error(context),
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading participants',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final participants = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.active) {
          _cachedParticipants = List.from(participants);
        }
        
        final filteredParticipants = _filterParticipants(participants);

        if (filteredParticipants.isEmpty) {
          return _buildEmptyState(participants.isEmpty, context);
        }

        return Column(
          children: filteredParticipants.map((participant) {
            return _buildParticipantCard(participant, context);
          }).toList(),
        );
      },
    );
  }

  // Stats widget with shimmer
  Widget _buildParticipantsStats(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      key: ValueKey(
        'stats-${widget.program.programId}-${_selectedMonth ?? 'regular'}-$_streamKey',
      ),
      stream: _getStatsStream(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerStats();
        }

        final data = snapshot.data ?? {
          'totalParticipants': 0,
          'paidParticipants': 0,
          'pendingParticipants': 0,
          'totalCollected': 0.0,
          'totalExpected': 0.0,
        };

        final int totalCount = data['totalParticipants'] ?? 0;
        final int paidCount = data['paidParticipants'] ?? 0;
        final int pendingCount = data['pendingParticipants'] ?? 0;
        final double totalCollected = data['totalCollected'] ?? 0.0;
        final double totalExpected = data['totalExpected'] ?? 0.0;

        final double progress = totalExpected > 0
            ? (totalCollected / totalExpected).clamp(0, 1)
            : 0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.program.isMonthlyPaymentProgram &&
                                _selectedMonth != null
                            ? "Monthly Summary"
                            : "Participants Overview",
                        style: TextStyle(
                          color: AppColors.textCards(context).withOpacity(0.9),
                          fontSize: 11,
                        ),
                      ),
                      if (widget.program.isMonthlyPaymentProgram &&
                          _selectedMonth != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            _formatMonthDisplay(_selectedMonth!),
                            style: TextStyle(
                              color: AppColors.textCards(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.people, 
                        color: AppColors.textCards(context),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        totalCount.toString(),
                        style: TextStyle(
                          color: AppColors.textCards(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                "₹${totalCollected.toStringAsFixed(0)}",
                style: TextStyle(
                  color: AppColors.textCards(context),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (totalExpected > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    "of ₹${totalExpected.toStringAsFixed(0)} expected",
                    style: TextStyle(
                      color: AppColors.textCards(context).withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.textCards(context).withOpacity(0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textCards(context),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _statChip(
                    context,
                    icon: Icons.check_circle,
                    label: "Paid",
                    value: paidCount,
                    color: AppColors.textCards(context),
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    context,
                    icon: Icons.pending,
                    label: "Pending",
                    value: pendingCount,
                    color: AppColors.textCards(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthGridSelector(BuildContext context) {
    if (_isLoadingMonths) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: LinearProgressIndicator(
          color: AppColors.primary(context),
        ),
      );
    }
    
    return Card(
      color: AppColors.card(context),
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.border(context),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        color: AppColors.primary(context),
                        size: 20,
                      ),
                      onPressed: _goToPreviousYear,
                      tooltip: 'Previous year',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    Text(
                      '$_currentDisplayYear',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: AppColors.primary(context),
                        size: 20,
                      ),
                      onPressed: _goToNextYear,
                      tooltip: 'Next year',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1.05,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthNumber = index + 1;
                final monthId = '$_currentDisplayYear-${monthNumber.toString().padLeft(2, '0')}';
                final paymentCount = _monthPaymentCounts[monthId] ?? 0;
                final hasPayments = paymentCount > 0;
                final isSelected = monthId == _selectedMonth;
                final isCurrentMonth = monthId == _formatMonthId(DateTime.now());
                final isFutureMonth = DateTime.parse('$monthId-01').isAfter(DateTime.now());
                
                return GestureDetector(
                  onTap: () {
                    if (monthId != _selectedMonth) {
                      setState(() {
                        _selectedMonth = monthId;
                        _streamKey++;
                        _showMonthSelector = false;
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary(context) : 
                             isFutureMonth ? AppColors.surface(context) : 
                             hasPayments ? AppColors.success(context).withOpacity(0.1) : 
                             AppColors.card(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary(context) : 
                               isCurrentMonth ? AppColors.warning(context) : 
                               AppColors.border(context),
                        width: isSelected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getShortMonthName(monthNumber),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white :
                                   isFutureMonth ? AppColors.textTertiary(context) :
                                   AppColors.textPrimary(context),
                          ),
                        ),
                        
                        const SizedBox(height: 1),
                        
                        if (hasPayments) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.9) : 
                                     AppColors.success(context).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$paymentCount',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.success(context) : 
                                       AppColors.success(context),
                              ),
                            ),
                          ),
                        ] else if (isFutureMonth) ...[
                          Icon(
                            Icons.schedule,
                            size: 8,
                            color: AppColors.textTertiary(context),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                        ],
                        
                        if (isCurrentMonth && !isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 0.5),
                            child: Icon(
                              Icons.circle,
                              size: 4,
                              color: AppColors.warning(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 6),
            
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildLegendItem(
                  AppColors.primary(context), 
                  'Selected',
                  context,
                ),
                _buildLegendItem(
                  AppColors.success(context).withOpacity(0.2), 
                  'Has Payments',
                  context,
                ),
                _buildLegendItem(
                  AppColors.warning(context), 
                  'Current',
                  context,
                ),
                _buildLegendItem(
                  AppColors.surface(context), 
                  'Future',
                  context,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelectorHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border(context),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: AppColors.primary(context),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Monthly Payments',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_selectedMonth != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _formatMonthDisplay(_selectedMonth!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary(context),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _showMonthSelector 
                              ? Icons.keyboard_arrow_up 
                              : Icons.keyboard_arrow_down,
                            color: AppColors.primary(context),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _showMonthSelector = !_showMonthSelector;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: _showMonthSelector ? 'Hide month selector' : 'Show month selector',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: AppColors.border(context),
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 9,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
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

  Stream<List<ParticipantModel>> _getParticipantsStream(BuildContext context) {
    final programProvider = context.read<ProgramProvider>();
    
    if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
      return programProvider.streamProgramParticipantsWithMonthlyContributions(
        widget.program.programId,
        _selectedMonth!,
      );
    } else {
      return programProvider.streamProgramParticipantsWithContributions(
        widget.program.programId,
      );
    }
  }

  Widget _statChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.textCards(context).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    color: AppColors.textCards(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textCards(context).withOpacity(0.85),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Stream<Map<String, dynamic>> _getStatsStream(BuildContext context) {
    final programProvider = context.read<ProgramProvider>();
    
    if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
      return programProvider.streamProgramMonthlyFinancialSummary(
        widget.program.programId,
        _selectedMonth!,
      );
    } else {
      return programProvider.streamProgramFinancialSummary(widget.program.programId);
    }
  }

  Widget _buildSearchFilterBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search participants...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.primary(context),
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.border(context),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.border(context),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary(context),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 14,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border(context),
            ),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppColors.primary(context),
                size: 20,
              ),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
              dropdownColor: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {
    final userName = participant.userName.isNotEmpty ? participant.userName : 'Unknown User';
    final contributionPaid = participant.contributionPaid ?? 0;
    final suggestedContribution = widget.program.suggestedContribution ?? 0;
    final hasPaidFull = suggestedContribution > 0 && contributionPaid >= suggestedContribution;
    final isMonthlyProgram = widget.program.isMonthlyPaymentProgram;

    return Column(
      
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showParticipantActions(participant, context);
            },
            child: Container(
                                       decoration: BoxDecoration(
      color: AppColors.card(context),
      // boxShadow: [
      //   BoxShadow(
      //     color: Colors.black.withOpacity(0.05),
      //     blurRadius: 12,
      //     offset: const Offset(0, 4),
      //   ),
      // ],
    ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary(context).withOpacity(0.12),
                    ),
                    child: Center(
                      child: Text(
                        userName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (suggestedContribution > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paid ₹${contributionPaid.toStringAsFixed(0)}/₹${suggestedContribution.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: hasPaidFull ? AppColors.success(context) : AppColors.warning(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!isMonthlyProgram)
                                const SizedBox(height: 4),
                              if (!isMonthlyProgram)
                                LinearProgressIndicator(
                                  value: suggestedContribution > 0 
                                    ? (contributionPaid / suggestedContribution).clamp(0.0, 1.0) 
                                    : 0,
                                  backgroundColor: AppColors.progressBackground(context),
                                  color: hasPaidFull ? AppColors.success(context) : AppColors.warning(context),
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                            ],
                          ),
                        if (suggestedContribution == 0)
                          Text(
                            'No contribution required',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPaidFull ? AppColors.success(context) : AppColors.warning(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasPaidFull ? 'Paid' : 'Pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border(context),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool noParticipants, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noParticipants ? Icons.people_outline : Icons.search_off,
              size: 60,
              color: AppColors.textTertiary(context),
            ),
            const SizedBox(height: 8),
            Text(
              noParticipants 
                ? widget.program.isMonthlyPaymentProgram
                  ? 'No Participants Yet for This Month'
                  : 'No Participants Yet'
                : 'No Matching Participants',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              noParticipants 
                ? widget.program.isMonthlyPaymentProgram
                  ? 'Participants will appear here when they pay for the selected month'
                  : 'Participants will appear here when they join the program'
                : 'Try adjusting your search or filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ParticipantModel> _filterParticipants(List<ParticipantModel> participants) {
    List<ParticipantModel> filtered = participants;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((participant) =>
        participant.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        participant.userEmail.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_filterStatus == 'paid') {
      filtered = filtered.where((p) {
        final suggestedContribution = widget.program.suggestedContribution ?? 0;
        final contributionPaid = p.contributionPaid ?? 0;
        return suggestedContribution > 0 && contributionPaid >= suggestedContribution;
      }).toList();
    } else if (_filterStatus == 'pending') {
      filtered = filtered.where((p) {
        final suggestedContribution = widget.program.suggestedContribution ?? 0;
        final contributionPaid = p.contributionPaid ?? 0;
        return suggestedContribution == 0 || contributionPaid < suggestedContribution;
      }).toList();
    }

    return filtered;
  }

void _showParticipantActions(ParticipantModel participant, BuildContext context) async {
  // Get payment status BEFORE showing bottom sheet
  final hasPaid = await _checkParticipantPaidStatus(
    participant.userId,
    widget.program.programId,
  );
  
  final subtitle = await _getPaymentSubtitleWithRealData(participant);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {},
            child: DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.25,
              maxChildSize: 0.4,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.only(right: 16, left: 16, top: 20, bottom: 0),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppColors.border(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToMemberProfile(participant, context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primary(context).withOpacity(0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.primary(context),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        participant.userName,
                                        style: TextStyle(
                                          color: AppColors.textPrimary(context),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (participant.userEmail.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            participant.userEmail,
                                            style: TextStyle(
                                              color: AppColors.textSecondary(context),
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 20,
                                  color: AppColors.primary(context),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        if (widget.program.suggestedContribution != null &&
                            widget.program.suggestedContribution! > 0)
                          _buildActionTile(
                            context: context,
                            icon: hasPaid
                                ? Icons.payment
                                : Icons.payment_outlined,
                            title: hasPaid ? 'Mark as Pending' : 'Mark as Paid', // Use real status
                            color: hasPaid
                                ? AppColors.success(context)
                                : AppColors.warning(context),
                            subtitle: subtitle, // Use real subtitle
                            onTap: () {
                              Navigator.pop(context);
                              _togglePaymentStatus(participant, context);
                            },
                          ),

                        _buildActionTile(
                          context: context,
                          icon: Icons.remove_circle_outline,
                          title: 'Remove from Program',
                          color: AppColors.error(context),
                          isDestructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            _showRemoveConfirmation(participant, context);
                          },
                        ),

                        const SizedBox(height: 0),

                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.card(context),
                              foregroundColor: AppColors.textPrimary(context),
                              side: BorderSide(color: AppColors.border(context)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}


  void _navigateToMemberProfile(ParticipantModel participant, BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final userService = UserService();
      final UserModel? member = await userService.getUserById(participant.userId);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (member == null) {
        final fallbackMember = UserModel(
          uid: participant.userId,
          email: participant.userEmail,
          displayName: participant.userName,
          isAdmin: false,
          isApproved: true,
          communityId: widget.program.communityId,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          phoneNumber: '',
        );
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailsScreen(member: fallbackMember),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailsScreen(member: member),
          ),
        );
      }
      
      // Refresh participants list after returning from member profile
      if (mounted) {
        setState(() {
          _streamKey++;
        });
      }
      
    } catch (error, stackTrace) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load member profile'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    String? subtitle,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDestructive 
                              ? AppColors.error(context) 
                              : AppColors.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isDestructive)
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary(context),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Also update the _getPaymentActionText method to use real-time check
String _getPaymentActionText(ParticipantModel participant) {
  // Since we can't make this async, we'll use the same logic based on contributionPaid
  // But the bottom sheet uses real-time check above
  final contributionPaid = participant.contributionPaid ?? 0;
  final suggestedAmount = widget.program.suggestedContribution ?? 0.0;
  
  if (suggestedAmount > 0 && contributionPaid >= suggestedAmount) {
    return 'Mark as Pending';
  } else {
    return 'Mark as Paid';
  }
}

String? _getPaymentSubtitle(ParticipantModel participant) {
  final contributionPaid = participant.contributionPaid ?? 0;
  final suggestedAmount = widget.program.suggestedContribution ?? 0.0;
  
  if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
    return 'For ${_formatMonthDisplay(_selectedMonth!)}';
  }
  
  if (suggestedAmount > 0) {
    if (contributionPaid >= suggestedAmount) {
      return 'Fully paid';
    } else {
      return '₹${contributionPaid.toStringAsFixed(0)}/₹${suggestedAmount.toStringAsFixed(0)}';
    }
  }
  return null;
}
// Clean, final version of _togglePaymentStatus
// Put this into lib/features/programs/screens/tabs/program_participants_tab.dart
// This version:
//  - captures context/resources early
//  - handles monthly vs regular programs correctly
//  - keeps UI state updates safe (checks mounted)
//  - logs useful debug output
//  - calls existing helpers: _createContribution, _removeContributions

Future<void> _togglePaymentStatus(
  ParticipantModel participant,
  BuildContext context,
) async {
  // Capture ALL context-dependent objects BEFORE any async operations
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final contributionProvider = context.read<ContributionProvider>();
  final successColor = AppColors.success(context);
  final errorColor = AppColors.error(context);
  final warningColor = AppColors.warning(context);
  
  // Also get other required values
  final programId = widget.program.programId;
  final communityId = widget.program.communityId;
  final isMonthlyProgram = widget.program.isMonthlyPaymentProgram;
  final suggestedAmount = widget.program.suggestedContribution ?? 0.0;

  debugPrint('🔧 _togglePaymentStatus: start for ${participant.userName}');

  // IMMEDIATELY check if widget is mounted
  if (!mounted) {
    debugPrint('❌ _togglePaymentStatus: widget not mounted — abort');
    return;
  }

  // Set loading state immediately
  setState(() => _updatingParticipants[participant.userId] = true);

  try {
    // Small delay to prevent rapid clicks
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Check mounted again after delay
    if (!mounted) {
      debugPrint('❌ Widget disposed during delay');
      return;
    }

    if (suggestedAmount <= 0) {
      debugPrint('⚠️ _togglePaymentStatus: suggested amount is zero or null');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('This program has no suggested contribution amount'),
            backgroundColor: warningColor,
          ),
        );
      }
      return;
    }

    // Clear cache ONCE before fetching
    contributionProvider.clearCacheForUser(programId, participant.userId);

    // Load existing contributions
    debugPrint('🔧 _togglePaymentStatus: fetching existing contributions');
    
    final contributions = await contributionProvider.getUserContributionsForProgram(
      programId,
      participant.userId,
      forceRefresh: true,
    );

    debugPrint('🔧 _togglePaymentStatus: got ${contributions.length} contributions');

    // --- MONTHLY PROGRAM ---
    if (isMonthlyProgram) {
      if (_selectedMonth == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Please select a month first'),
            backgroundColor: warningColor,
          ),
        );
        return;
      }

      // Get all contributions for this month
      final monthlyContributions = contributions.where(
        (c) => c.isMonthlyContribution && c.monthId == _selectedMonth,
      ).toList();

      final totalPaid = monthlyContributions.fold<double>(
        0.0,
        (sum, c) => sum + c.amount,
      );

      debugPrint(
        '🔧 Monthly total paid for $_selectedMonth = ₹$totalPaid / ₹$suggestedAmount',
      );

      if (totalPaid >= suggestedAmount) {
        // ✅ Fully paid → mark as pending (remove all contributions for this month)
        debugPrint('🔧 Fully paid → removing monthly contributions');
        
        await _removeContributions(
          contributionProvider: contributionProvider,
          scaffoldMessenger: scaffoldMessenger,
          programId: programId,
          userId: participant.userId,
          participantName: participant.userName,
          monthId: _selectedMonth,
          isMonthlyProgram: true,
        );
      } else {
        // ⚠️ Not fully paid → add remaining amount
        final remaining = suggestedAmount - totalPaid;
        debugPrint('🔧 Not fully paid → adding ₹$remaining');
        
        await _createContribution(
          contributionProvider: contributionProvider,
          scaffoldMessenger: scaffoldMessenger,
          programId: programId,
          communityId: communityId,
          userId: participant.userId,
          participantName: participant.userName,
          amount: remaining,
          monthId: _selectedMonth,
          isMonthlyProgram: true,
        );
      }
      return;
    }

    // --- REGULAR PROGRAM ---
    // Get only non-monthly contributions for regular programs
    final nonMonthlyContributions = contributions.where((c) => !c.isMonthlyContribution).toList();
    
    // Calculate total paid from non-monthly contributions
    final totalPaid = nonMonthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
    debugPrint('🔧 _togglePaymentStatus: total paid = ₹$totalPaid of ₹$suggestedAmount');

    if (totalPaid >= suggestedAmount) {
      // ✅ Fully paid → mark as pending (remove all contributions)
      debugPrint('🔧 Fully paid → removing all contributions');
      
      await _removeContributions(
        contributionProvider: contributionProvider,
        scaffoldMessenger: scaffoldMessenger,
        programId: programId,
        userId: participant.userId,
        participantName: participant.userName,
        monthId: null,
        isMonthlyProgram: false,
      );
    } else {
      // ⚠️ Not fully paid → add remaining amount to reach full payment
      final remaining = suggestedAmount - totalPaid;
      debugPrint('🔧 Not fully paid → adding remaining ₹$remaining to reach full payment');
      
      await _createContribution(
        contributionProvider: contributionProvider,
        scaffoldMessenger: scaffoldMessenger,
        programId: programId,
        communityId: communityId,
        userId: participant.userId,
        participantName: participant.userName,
        amount: remaining, // This adds the remaining amount needed
        monthId: null,
        isMonthlyProgram: false,
      );
    }

  } catch (error, stackTrace) {
    debugPrint('❌ ERROR in _togglePaymentStatus: $error');
    debugPrint(stackTrace.toString());
    
    // Use the captured scaffoldMessenger (no context access needed)
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Failed to update payment status'),
        backgroundColor: errorColor,
      ),
    );
  } finally {
    // Always clear loading state
    if (mounted) {
      setState(() {
        _updatingParticipants.remove(participant.userId);
        _streamKey++; // Trigger UI refresh
      });
    }
    
    debugPrint('🔧 _togglePaymentStatus: finished for ${participant.userName}');
  }
}

// Update your UI button logic to always show "Mark as Pending" until fully paid
Widget _buildPaymentButton(ParticipantModel participant) {
  final totalPaid = _calculateTotalPaid(participant.userId); // Implement this
  final suggestedAmount = widget.program.suggestedContribution ?? 0.0;
  final isFullyPaid = totalPaid >= suggestedAmount;
  
  return ElevatedButton(
    onPressed: () => _togglePaymentStatus(participant, context),
    style: ElevatedButton.styleFrom(
      backgroundColor: isFullyPaid ? Colors.green : Colors.orange,
    ),
    child: Text(
      isFullyPaid ? 'Mark as Pending' : 'Mark as Pending',
      style: TextStyle(color: Colors.white),
    ),
  );
}

// Helper method to calculate total paid
double _calculateTotalPaid(String userId) {
  // Implement based on your data structure
  // This should return the total amount paid by this user
  return 0.0;
}

// Helper method that doesn't access context
Future<void> _createContribution({
  required ContributionProvider contributionProvider,
  required ScaffoldMessengerState scaffoldMessenger,
  required String programId,
  required String communityId,
  required String userId,
  required String participantName,
  required double amount,
  required String? monthId,
  required bool isMonthlyProgram,
}) async {
  try {
    final contributionId = '${DateTime.now().millisecondsSinceEpoch}_$userId';
    
    String note;
    if (monthId != null) {
      note = 'Admin marked as paid for ${_formatMonthDisplay(monthId)}';
    } else {
      note = 'Admin marked as fully paid';
    }
    
  final contribution = ContributionModel(
  contributionId: contributionId,
  programId: programId,
  userId: userId,
  contributorName: participantName, // ADD THIS REQUIRED FIELD
  communityId: communityId,
  amount: amount,
  paymentMethod: 'cash',
  isMonthlyContribution: isMonthlyProgram,
  monthId: monthId,
);
    
    await contributionProvider.addContribution(contribution);
    
    // Clear cache after creation
    contributionProvider.clearCacheForUser(programId, userId);
    
    String message = monthId != null
        ? 'Marked $participantName as paid for ${_formatMonthDisplay(monthId)}'
        : 'Marked $participantName as paid';
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
  } catch (error, stackTrace) {
    debugPrint('❌ ERROR in _createContribution: $error');
    debugPrint(stackTrace.toString());
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Failed to create contribution'),
        backgroundColor: Colors.red,
      ),
    );
    
    rethrow;
  }
}

// Helper method that doesn't access context
Future<void> _removeContributions({
  required ContributionProvider contributionProvider,
  required ScaffoldMessengerState scaffoldMessenger,
  required String programId,
  required String userId,
  required String participantName,
  required String? monthId,
  required bool isMonthlyProgram,
}) async {
  try {
    // Get fresh contributions
    final contributions = await contributionProvider.getUserContributionsForProgram(
      programId,
      userId,
      forceRefresh: true,
    );
    
    List<String> contributionsToDelete = [];
    
    if (isMonthlyProgram && monthId != null) {
      // Delete only the specific month's contribution
      contributionsToDelete = contributions
          .where((c) => c.isMonthlyContribution && c.monthId == monthId)
          .map((c) => c.contributionId)
          .toList();
    } else {
      // Delete all non-monthly contributions
      contributionsToDelete = contributions
          .where((c) => !c.isMonthlyContribution)
          .map((c) => c.contributionId)
          .toList();
    }
    
    debugPrint('🔧 _removeContributions: deleting ${contributionsToDelete.length} contributions');
    
    // Delete all identified contributions
    for (final contributionId in contributionsToDelete) {
      await contributionProvider.deleteContribution(contributionId);
    }
    
    // Clear cache after deletion
    contributionProvider.clearCacheForUser(programId, userId);
    
    String message = isMonthlyProgram && monthId != null
        ? 'Marked $participantName as pending for ${_formatMonthDisplay(monthId!)}'
        : 'Marked $participantName as pending';
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
    
  } catch (error, stackTrace) {
    debugPrint('❌ ERROR in _removeContributions: $error');
    debugPrint(stackTrace.toString());
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Failed to update payment status'),
        backgroundColor: Colors.red,
      ),
    );
    
    rethrow;
  }
}
  void _showRemoveConfirmation(ParticipantModel participant, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text(
          'Remove Participant',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${participant.userName} from this program?',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeParticipant(participant, context);
            },
            child: Text(
              'Remove',
              style: TextStyle(
                color: AppColors.error(context),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeParticipant(ParticipantModel participant, BuildContext context) async {
    try {
      final participantProvider = context.read<ParticipantProvider>();
      await participantProvider.leaveProgram(participant.programId, participant.userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${participant.userName} from program'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to remove participant'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }
  Future<bool> _checkParticipantPaidStatus(
  String userId,
  String programId,
) async {
  try {
    final contributionProvider = context.read<ContributionProvider>();
    final suggestedAmount = widget.program.suggestedContribution ?? 0.0;
    
    if (suggestedAmount <= 0) return false;
    
    // Get user's contributions
    final contributions = await contributionProvider.getUserContributionsForProgram(
      programId,
      userId,
      forceRefresh: true,
    );
    
    if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
      // Check monthly contributions for selected month
      final monthlyContributions = contributions
          .where((c) => c.isMonthlyContribution && c.monthId == _selectedMonth)
          .toList();
      
      final totalPaid = monthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
      return totalPaid >= suggestedAmount;
    } else {
      // Check regular contributions
      final nonMonthlyContributions = contributions
          .where((c) => !c.isMonthlyContribution)
          .toList();
      
      final totalPaid = nonMonthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
      return totalPaid >= suggestedAmount;
    }
  } catch (error) {
    debugPrint('❌ Error checking payment status: $error');
    return false;
  }
}

// Method to get payment subtitle with real data
Future<String?> _getPaymentSubtitleWithRealData(ParticipantModel participant) async {
  try {
    final contributionProvider = context.read<ContributionProvider>();
    final suggestedAmount = widget.program.suggestedContribution ?? 0.0;
    
    if (suggestedAmount <= 0) {
      return widget.program.isMonthlyPaymentProgram && _selectedMonth != null
          ? 'For ${_formatMonthDisplay(_selectedMonth!)}'
          : null;
    }
    
    // Get user's contributions
    final contributions = await contributionProvider.getUserContributionsForProgram(
      widget.program.programId,
      participant.userId,
      forceRefresh: true,
    );
    
    double totalPaid;
    
    if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
      // Get monthly contributions
      final monthlyContributions = contributions
          .where((c) => c.isMonthlyContribution && c.monthId == _selectedMonth)
          .toList();
      
      totalPaid = monthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
      
      if (totalPaid >= suggestedAmount) {
        return 'Fully paid for ${_formatMonthDisplay(_selectedMonth!)}';
      } else {
        return '₹${totalPaid.toStringAsFixed(0)}/₹${suggestedAmount.toStringAsFixed(0)} for ${_formatMonthDisplay(_selectedMonth!)}';
      }
    } else {
      // Get regular contributions
      final nonMonthlyContributions = contributions
          .where((c) => !c.isMonthlyContribution)
          .toList();
      
      totalPaid = nonMonthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
      
      if (totalPaid >= suggestedAmount) {
        return 'Fully paid';
      } else {
        return '₹${totalPaid.toStringAsFixed(0)}/₹${suggestedAmount.toStringAsFixed(0)}';
      }
    }
  } catch (error) {
    debugPrint('❌ Error getting payment subtitle: $error');
    return null;
  }
}
}