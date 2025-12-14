// ✅ FIXED: Stats logic and auto-close month selector
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/program_model.dart';
import '../../providers/program_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../../core/constants/app_colors.dart';

class ProgramParticipantsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramParticipantsTab({super.key, required this.program});

  @override
  State<ProgramParticipantsTab> createState() => _ProgramParticipantsTabState();
}

class _ProgramParticipantsTabState extends State<ProgramParticipantsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all';
  
  String? _selectedMonth;
  List<String> _availableMonths = [];
  bool _isLoadingMonths = false;
  Map<String, int> _monthPaymentCounts = {};
  int _streamKey = 0;
  int _currentDisplayYear = DateTime.now().year;
  bool _showMonthSelector = false;

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
      final programProvider = Provider.of<ProgramProvider>(context, listen: false);
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

  List<String> _getMonthsForYear(int year) {
    return [
      '$year-01', '$year-02', '$year-03', '$year-04',
      '$year-05', '$year-06', '$year-07', '$year-08',
      '$year-09', '$year-10', '$year-11', '$year-12',
    ];
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
  return ListView(
    padding: const EdgeInsets.all(8),
    children: [
      _buildParticipantsStats(context),
      
      if (widget.program.isMonthlyPaymentProgram) 
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: _buildMonthSelectorHeader(context),
        ),
      
      if (_showMonthSelector && widget.program.isMonthlyPaymentProgram)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildMonthGridSelector(context),
        ),
      
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _buildSearchFilterBar(context),
      ),
      
      _buildParticipantsListForScrollView(context), // Need to modify this method
    ],
  );
}
// Modified for use with parent scroll view
Widget _buildParticipantsListForScrollView(BuildContext context) {
  return StreamBuilder<List<ParticipantModel>>(
    key: ValueKey('participants-${widget.program.programId}-${_selectedMonth ?? 'regular'}-$_streamKey'),
    stream: _getParticipantsStream(context),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CircularProgressIndicator(
              color: AppColors.primary(context),
            ),
          ),
        );
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
                SizedBox(height: 8),
                Text(
                  'Error loading participants',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    if (widget.program.isMonthlyPaymentProgram) {
                      _initializeMonths();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final participants = snapshot.data ?? [];
      final filteredParticipants = _filterParticipants(participants);

      if (filteredParticipants.isEmpty) {
        return _buildEmptyState(participants.isEmpty, context);
      }

      return Column(
        children: filteredParticipants.map((participant) {
          return Padding(
            padding: const EdgeInsets.only(bottom:0 ),
            child: _buildParticipantCard(participant, context),
          );
        }).toList(),
      );
    },
  );
}
  // ✅ RESTORED: Participants list builder
  Widget _buildParticipantsList(BuildContext context) {
    return StreamBuilder<List<ParticipantModel>>(
      key: ValueKey('participants-${widget.program.programId}-${_selectedMonth ?? 'regular'}-$_streamKey'),
      stream: _getParticipantsStream(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.primary(context),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: AppColors.error(context),
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Error loading participants',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    if (widget.program.isMonthlyPaymentProgram) {
                      _initializeMonths();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final participants = snapshot.data ?? [];
        final filteredParticipants = _filterParticipants(participants);

        if (filteredParticipants.isEmpty) {
          return _buildEmptyState(participants.isEmpty, context);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 2), // ✅ Reduced bottom padding
          itemCount: filteredParticipants.length,
          itemBuilder: (context, index) {
            final participant = filteredParticipants[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 0), // ✅ REDUCED from 8 to 2px
              child: _buildParticipantCard(participant, context),
            );
          },
        );
      },
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
                        SizedBox(width: 8),
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
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        SizedBox(width: 8),
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
                          constraints: BoxConstraints(),
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
Widget _buildMonthGridSelector(BuildContext context) {
  if (_isLoadingMonths) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4), // Reduced from 8 to 4
      child: LinearProgressIndicator(
        color: AppColors.primary(context),
      ),
    );
  }
  
  return Card(
    color: AppColors.card(context),
    elevation: 1, // Reduced from 2 to 1
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(10), // Reduced from 12 to 10
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(10), // Reduced from 12 to 10
              border: Border.all(
                color: AppColors.border(context),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), // Reduced padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: AppColors.primary(context),
                      size: 20, // Smaller icon
                    ),
                    onPressed: _goToPreviousYear,
                    tooltip: 'Previous year',
                    padding: EdgeInsets.all(4), // Reduced padding
                    constraints: BoxConstraints(
                      minWidth: 36, // Smaller constraints
                      minHeight: 36,
                    ),
                  ),
                  Text(
                    '$_currentDisplayYear',
                    style: TextStyle(
                      fontSize: 16, // Reduced from 18 to 16
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: AppColors.primary(context),
                      size: 20, // Smaller icon
                    ),
                    onPressed: _goToNextYear,
                    tooltip: 'Next year',
                    padding: EdgeInsets.all(4), // Reduced padding
                    constraints: BoxConstraints(
                      minWidth: 36, // Smaller constraints
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 8), // Reduced from 12 to 8
          
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 4, // Reduced from 6 to 4
              mainAxisSpacing: 4, // Reduced from 6 to 4
              childAspectRatio: 1.05, // Reduced from 1.1 to 1.05
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
                    borderRadius: BorderRadius.circular(10), // Reduced from 12 to 10
                    border: Border.all(
                      color: isSelected ? AppColors.primary(context) : 
                             isCurrentMonth ? AppColors.warning(context) : 
                             AppColors.border(context),
                      width: isSelected ? 1.5 : 0.8, // Reduced border width
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getShortMonthName(monthNumber),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13, // Reduced from 14 to 13
                          color: isSelected ? Colors.white :
                                 isFutureMonth ? AppColors.textTertiary(context) :
                                 AppColors.textPrimary(context),
                        ),
                      ),
                      
                      SizedBox(height: 1), // Reduced from 2 to 1
                      
                      if (hasPayments) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 3, vertical: 0), // Further reduced
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.9) : 
                                   AppColors.success(context).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4), // Reduced from 6 to 4
                          ),
                          child: Text(
                            '$paymentCount',
                            style: TextStyle(
                              fontSize: 8, // Reduced from 9 to 8
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.success(context) : 
                                     AppColors.success(context),
                            ),
                          ),
                        ),
                      ] else if (isFutureMonth) ...[
                        Icon(
                          Icons.schedule,
                          size: 8, // Reduced from 10 to 8
                          color: AppColors.textTertiary(context),
                        ),
                      ] else ...[
                        SizedBox(height: 10), // Reduced from 12 to 10
                      ],
                      
                      if (isCurrentMonth && !isSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 0.5), // Reduced padding
                          child: Icon(
                            Icons.circle,
                            size: 4, // Reduced from 5 to 4
                            color: AppColors.warning(context),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          SizedBox(height: 6), // Reduced from 8 to 6
          
          Wrap(
            spacing: 4, // Reduced from 6 to 4
            runSpacing: 4, // Reduced from 6 to 4
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

Widget _buildLegendItem(Color color, String text, BuildContext context) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8, // Reduced from 10 to 8
        height: 8, // Reduced from 10 to 8
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: AppColors.border(context),
            width: 0.5, // Reduced border width
          ),
        ),
      ),
      SizedBox(width: 3), // Reduced from 4 to 3
      Text(
        text,
        style: TextStyle(
          fontSize: 9, // Reduced from 10 to 9
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
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    
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

Widget _buildParticipantsStats(BuildContext context) {
  return StreamBuilder<Map<String, dynamic>>(
    key: ValueKey(
      'stats-${widget.program.programId}-${_selectedMonth ?? 'regular'}-$_streamKey',
    ),
    stream: _getStatsStream(context),
    builder: (context, snapshot) {
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
        padding: const EdgeInsets.all(12), // Reduced from 16 to 12
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient(context),
          borderRadius: BorderRadius.circular(16), // Reduced from 18 to 16
          boxShadow: [
            BoxShadow(
              blurRadius: 6, // Reduced from 10 to 6
              offset: const Offset(0, 2), // Reduced from 4 to 2
              color: Colors.black.withOpacity(0.06), // Reduced opacity
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ───────────────── Header ─────────────────
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
                      // CHANGED: Using AppColors.textSecondary
                      style: TextStyle(
                        color: AppColors.textCards(context).withOpacity(0.9),
                        fontSize: 11, // Reduced from 12 to 11
                      ),
                    ),
                    if (widget.program.isMonthlyPaymentProgram &&
                        _selectedMonth != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1), // Reduced from 2 to 1
                        child: Text(
                          _formatMonthDisplay(_selectedMonth!),
                          // CHANGED: Using AppColors.textSecondary with higher opacity
                          style: TextStyle(
                            color: AppColors.textCards(context),
                            fontSize: 13, // Reduced from 15 to 13
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
                      color: AppColors.textCards(context), // CHANGED: Using AppColors.textSecondary
                      size: 16,
                    ),
                    const SizedBox(width: 4), // Reduced from 6 to 4
                    Text(
                      totalCount.toString(),
                      // CHANGED: Using AppColors.textSecondary
                      style: TextStyle(
                        color: AppColors.textCards(context),
                        fontSize: 16, // Reduced from 18 to 16
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10), // Reduced from 16 to 10

            /// ───────────────── Amount ─────────────────
            Text(
              "₹${totalCollected.toStringAsFixed(0)}",
              // CHANGED: Using AppColors.textSecondary
              style: TextStyle(
                color: AppColors.textCards(context),
                fontSize: 26, // Reduced from 30 to 26
                fontWeight: FontWeight.bold,
              ),
            ),
            if (totalExpected > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2), // Reduced from 4 to 2
                child: Text(
                  "of ₹${totalExpected.toStringAsFixed(0)} expected",
                  // CHANGED: Using AppColors.textSecondary with opacity
                  style: TextStyle(
                    color: AppColors.textCards(context).withOpacity(0.85),
                    fontSize: 11, // Reduced from 12 to 11
                  ),
                ),
              ),

            const SizedBox(height: 8), // Reduced from 10 to 8

            /// ───────────────── Progress Bar ─────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6), // Reduced from 8 to 6
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6, // Reduced from 8 to 6
                backgroundColor: AppColors.textCards(context).withOpacity(0.25), // CHANGED
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textCards(context),
                ),
              ),
            ),

            const SizedBox(height: 10), // Reduced from 16 to 10

            /// ───────────────── Stats Chips ─────────────────
            Row(
              children: [
                _statChip(
                  context,
                  icon: Icons.check_circle,
                  label: "Paid",
                  value: paidCount,
                  color: AppColors.textCards(context),
                ),
                const SizedBox(width: 8), // Reduced from 12 to 8
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

Widget _statChip(
  BuildContext context, {
  required IconData icon,
  required String label,
  required int value,
  required Color color,
}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), // Reduced padding
      decoration: BoxDecoration(
        color: AppColors.textCards(context).withOpacity(0.15), // CHANGED
        borderRadius: BorderRadius.circular(12), // Reduced from 14 to 12
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16), // Reduced from 18 to 16
          const SizedBox(width: 6), // Reduced from 8 to 6
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                // CHANGED: Using AppColors.textSecondary
                style: TextStyle(
                  color: AppColors.textCards(context),
                  fontSize: 14, // Reduced from 16 to 14
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                // CHANGED: Using AppColors.textSecondary with opacity
                style: TextStyle(
                  color: AppColors.textCards(context).withOpacity(0.85),
                  fontSize: 10, // Reduced from 11 to 10
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
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    
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
                color: AppColors.textTertiary(context),
                fontSize: 13, // ✅ Smaller font
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.textSecondary(context),
                size: 18, // ✅ Smaller icon
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
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), // ✅ Reduced padding
            ),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 13, // ✅ Smaller font
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        SizedBox(width: 6), // ✅ Reduced spacing
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6), // ✅ Reduced padding
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
                color: AppColors.textSecondary(context),
                size: 18, // ✅ Smaller icon
              ),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 12, // ✅ Smaller font
              ),
              dropdownColor: AppColors.card(context),
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

    return Card(
      color: AppColors.card(context),
      elevation: 0.5, // ✅ Reduced elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // ✅ Smaller radius
        side: BorderSide(
          color: AppColors.border(context),
          width: 0.5, // ✅ Thinner border
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), // ✅ Reduced padding
        minLeadingWidth: 36, // ✅ Reduced leading width
        leading: CircleAvatar(
          radius: 24, // ✅ Smaller avatar
          backgroundColor: AppColors.primary(context).withOpacity(0.1),
          child: Text(
            userName.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary(context),
              fontSize: 18, // ✅ Smaller font
            ),
          ),
        ),
        title: Text(
          userName,
          style: TextStyle(
            fontWeight: FontWeight.w600, // ✅ Slightly lighter weight
            color: AppColors.textPrimary(context),
            fontSize: 15, // ✅ Smaller font
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (suggestedContribution > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 2), // ✅ Reduced spacing
                  Text(
                    'paid ₹${contributionPaid.toStringAsFixed(0)}/₹${suggestedContribution.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11, // ✅ Smaller font
                      fontWeight: FontWeight.w500,
                      color: hasPaidFull ? AppColors.success(context) : AppColors.warning(context),
                    ),
                  ),
                  if (!isMonthlyProgram)
                    SizedBox(height: 2), // ✅ Reduced spacing
                  if (!isMonthlyProgram)
                    LinearProgressIndicator(
                      value: suggestedContribution > 0 
                        ? (contributionPaid / suggestedContribution).clamp(0.0, 1.0) 
                        : 0,
                      backgroundColor: AppColors.progressBackground(context),
                      color: hasPaidFull ? AppColors.success(context) : AppColors.warning(context),
                      minHeight: 4, // ✅ Thinner progress bar
                      borderRadius: BorderRadius.circular(2),
                    ),
                ],
              ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), // ✅ Reduced padding
          decoration: BoxDecoration(
            color: hasPaidFull ? AppColors.success(context) : AppColors.warning(context),
            borderRadius: BorderRadius.circular(8), // ✅ Smaller radius
          ),
          child: Text(
            hasPaidFull ? 'Paid' : 'Pending',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9, // ✅ Smaller font
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          _showParticipantActions(participant, context);
        },
      ),
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
              size: 60, // ✅ Smaller icon
              color: AppColors.textTertiary(context),
            ),
            SizedBox(height: 8),
            Text(
              noParticipants 
                ? widget.program.isMonthlyPaymentProgram
                  ? 'No Participants Yet for This Month'
                  : 'No Participants Yet'
                : 'No Matching Participants',
              style: TextStyle(
                fontSize: 16, // ✅ Smaller font
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              noParticipants 
                ? widget.program.isMonthlyPaymentProgram
                  ? 'Participants will appear here when they pay for the selected month'
                  : 'Participants will appear here when they join the program'
                : 'Try adjusting your search or filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12, // ✅ Smaller font
              ),
            ),
            if (widget.program.isMonthlyPaymentProgram && !noParticipants)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: _initializeMonths,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ✅ Reduced padding
                    minimumSize: Size(0, 32), // ✅ Smaller button
                  ),
                  child: Text(
                    'Refresh Months',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12, // ✅ Smaller font
                    ),
                  ),
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

  void _showParticipantActions(ParticipantModel participant, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.person,
                  color: AppColors.primary(context),
                  size: 20, // ✅ Smaller icon
                ),
                title: Text(
                  'View Profile',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 13, // ✅ Smaller font
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              if (widget.program.suggestedContribution != null && widget.program.suggestedContribution! > 0)
                ListTile(
                  leading: Icon(
                    participant.hasPaidContribution ? Icons.payment : Icons.payment_outlined,
                    color: participant.hasPaidContribution ? AppColors.success(context) : AppColors.warning(context),
                    size: 20, // ✅ Smaller icon
                  ),
                  title: Text(
                    widget.program.isMonthlyPaymentProgram && _selectedMonth != null
                      ? participant.hasPaidContribution 
                        ? 'Mark as Pending for ${_formatMonthDisplay(_selectedMonth!)}'
                        : 'Mark as Paid for ${_formatMonthDisplay(_selectedMonth!)}'
                      : participant.hasPaidContribution ? 'Mark as Pending' : 'Mark as Paid',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13, // ✅ Smaller font
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePaymentStatus(participant, context);
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.error(context),
                  size: 20, // ✅ Smaller icon
                ),
                title: Text(
                  'Remove from Program',
                  style: TextStyle(
                    color: AppColors.error(context),
                    fontSize: 13, // ✅ Smaller font
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveConfirmation(participant, context);
                },
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13, // ✅ Smaller font
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _togglePaymentStatus(ParticipantModel participant, BuildContext context) {
    if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${participant.hasPaidContribution ? 'Unmark' : 'Mark'} payment for ${participant.userName} - ${_formatMonthDisplay(_selectedMonth!)}',
          ),
          backgroundColor: AppColors.primary(context),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment status toggle for ${participant.userName}'),
          backgroundColor: AppColors.primary(context),
        ),
      );
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
            fontSize: 16, // ✅ Smaller font
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${participant.userName} from this program?',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13, // ✅ Smaller font
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13, // ✅ Smaller font
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
                fontSize: 13, // ✅ Smaller font
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeParticipant(ParticipantModel participant, BuildContext context) async {
    try {
      final participantProvider = Provider.of<ParticipantProvider>(context, listen: false);
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
          content: Text('Failed to remove participant: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }
}