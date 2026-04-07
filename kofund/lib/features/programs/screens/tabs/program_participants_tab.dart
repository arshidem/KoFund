// ✅ FIXED: Stats logic and auto-close month selector
// ✅ ADDED: Skeleton shimmer effect for loading state
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/program_model.dart';
import '../../providers/program_provider.dart';
import '../../../participants/models/participant_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../participants/providers/participant_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/features/members/screens/member_details_screen.dart';
import 'package:kofund/features/programs/screens/add_participant_screen.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

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

  void _onRefresh() async {
    try {
      setState(() {
        _streamKey++;
      });
    } catch (error) {
      debugPrint("Refresh error: $error");
    }
  }

  void _initializeMonths() async {
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

  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    
    if (currentUser == null) return false;
    if (currentUser.uid == widget.program.createdBy) return true;
    if (currentUser.role == 'admin') return true;
    if (currentUser.isAdmin == true) return true;
    
    return false;
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

    if (result == true) {
      setState(() {
        _streamKey++;
      });
    }
  }

  // ✅ New Pinned Header Delegate
  Widget _buildPinnedSearchFilter(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverPinnedHeaderDelegate(
        minExtent: 64,
        maxExtent: 64,
        child: Container(
          color: AppColors.background(context),
          padding: const EdgeInsets.only(bottom: 8, top: 4, left: AppDimensions.screenPaddingHorizontal, right: AppDimensions.screenPaddingHorizontal),
          child: _buildSearchFilterBar(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin(context);

    return Stack(
      children: [
        Container(
          color: AppColors.background(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  _onRefresh();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
              ),
              
              SliverToBoxAdapter(
                child: _buildParticipantsStats(context),
              ),

              if (widget.program.isMonthlyPaymentProgram)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
                    child: _buildMonthSelectorHeader(context),
                  ),
                ),

              if (_showMonthSelector && widget.program.isMonthlyPaymentProgram)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildMonthGridSelector(context),
                  ),
                ),

              // STICKY HEADER for Search & Filter
              _buildPinnedSearchFilter(context),

              _buildParticipantsListSliver(context),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 88),
              ),
            ],
          ),
        ),

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
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsListSliver(BuildContext context) {
    return StreamBuilder<List<ParticipantModel>>(
      key: ValueKey('participants-${widget.program.programId}-${_selectedMonth ?? 'regular'}-$_streamKey'),
      stream: _getParticipantsStream(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedParticipants.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildShimmerSkeleton(),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: AppColors.error(context), size: 48),
                    const SizedBox(height: 8),
                    Text('Error loading participants', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)), textAlign: TextAlign.center),
                  ],
                ),
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
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(participants.isEmpty, context),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _buildParticipantCard(filteredParticipants[index], context);
            },
            childCount: filteredParticipants.length,
          ),
        );
      },
    );
  }


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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              // 🏆 Main Stats Card (Gap Layout Style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary(context).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.program.isMonthlyPaymentProgram && _selectedMonth != null
                              ? "Monthly Summary"
                              : "Participants Overview",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_alt_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                totalCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "₹${totalCollected.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    if (totalExpected > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "of ₹${totalExpected.toStringAsFixed(0)} expected",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 🚀 Secondary Row with Gap
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      label: "PAID",
                      value: paidCount.toString(),
                      icon: Icons.check_circle_rounded,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      label: "PENDING",
                      value: pendingCount.toString(),
                      icon: Icons.error_rounded,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card(context) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSkeleton() {
    return Column(
      children: List.generate(5, (index) => _buildShimmerParticipantCard()),
    );
  }

  Widget _buildShimmerParticipantCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface(context))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 16, decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 14, decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
              Container(width: 60, height: 24, decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(12))),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.border(context)),
      ],
    );
  }

  Widget _buildShimmerStats() {
    return Container(
      height: 180,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(24)),
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
                             hasPayments ? AppColors.success(context).withValues(alpha: 0.1) : 
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
                              color: isSelected ? Colors.white.withValues(alpha: 0.9) : 
                                     AppColors.success(context).withValues(alpha: 0.2),
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
                  AppColors.success(context).withValues(alpha: 0.2), 
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.border(context).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary(context),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Monthly Payments',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (_selectedMonth != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(
                        color: AppColors.primary(context).withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _formatMonthDisplay(_selectedMonth!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _showMonthSelector = !_showMonthSelector;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _showMonthSelector 
                          ? Icons.keyboard_arrow_up_rounded 
                          : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary(context),
                        size: 22,
                      ),
                    ),
                  ),
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
          color: AppColors.textCards(context).withValues(alpha: 0.15),
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
                    color: AppColors.textCards(context).withValues(alpha: 0.85),
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
    return Container(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.border(context).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search participants...',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.primary(context),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Filter Button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: AppColors.border(context).withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary(context),
                  size: 20,
                ),
                offset: const Offset(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  setState(() {
                    _filterStatus = value;
                  });
                },
                itemBuilder: (context) => [
                  _buildFilterMenuItem('all', 'All Status', Icons.list_alt_rounded),
                  _buildFilterMenuItem('paid', 'Paid Only', Icons.check_circle_outline_rounded),
                  _buildFilterMenuItem('pending', 'Pending Only', Icons.pending_outlined),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(String value, String label, IconData icon) {
    final isSelected = _filterStatus == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.primary(context) : AppColors.textSecondary(context),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {
  final userName = participant.userName.isNotEmpty ? participant.userName : 'Unknown User';
  final contributionPaid = participant.contributionPaid ?? 0;
  final suggestedContribution = widget.program.suggestedContribution ?? 0;
  final hasPaidFull = suggestedContribution > 0 && contributionPaid >= suggestedContribution;

  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _navigateToMemberProfile(participant, context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Column 1: Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary(context).withValues(alpha: 0.12),
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
                
                // Column 2: Name and Contribution
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(height: 2),
                      if (suggestedContribution > 0)
                        Text(
                          'Paid ₹${contributionPaid.toStringAsFixed(0)}/₹${suggestedContribution.toStringAsFixed(0)}',
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
                
                const SizedBox(width: 8),
                
               if (suggestedContribution > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPaidFull 
                          ? AppColors.success(context).withValues(alpha: 0.15)
                          : AppColors.warning(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasPaidFull 
                            ? AppColors.success(context).withValues(alpha: 0.3)
                            : AppColors.warning(context).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasPaidFull 
                                ? AppColors.success(context)
                                : AppColors.warning(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasPaidFull ? 'Paid' : 'Pending',
                          style: TextStyle(
                            color: hasPaidFull 
                                ? AppColors.success(context)
                                : AppColors.warning(context),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Column 4: Three-dot menu - Use PopupMenuButton directly
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppColors.textTertiary(context),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onSelected: (value) async {
                    if (value == 'toggle_payment') {
                      _togglePaymentStatus(participant, context);
                    } else if (value == 'remove') {
                      _showRemoveConfirmation(participant, context);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'toggle_payment',
                        child: FutureBuilder<bool>(
                          future: _checkParticipantPaidStatus(
                            participant.userId,
                            widget.program.programId,
                          ),
                          builder: (context, snapshot) {
                            final isPaid = snapshot.data ?? false;
                            return FutureBuilder<String?>(
                              future: _getPaymentSubtitleWithRealData(participant),
                              builder: (context, subtitleSnapshot) {
                                final subtitle = subtitleSnapshot.data;
                                return Row(
                                  children: [
                                    Icon(
                                      isPaid ? Icons.payment : Icons.payment_outlined,
                                      color: isPaid ? AppColors.success(context) : AppColors.warning(context),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isPaid ? 'Mark as Pending' : 'Mark as Paid',
                                            style: TextStyle(
                                              color: AppColors.textPrimary(context),
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
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.error(context),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Remove from Program',
                              style: TextStyle(
                                color: AppColors.error(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
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
            const SizedBox(height: 16),
            Text(
              noParticipants 
                ? 'No participants yet' 
                : 'No results found',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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

  void _navigateToMemberProfile(ParticipantModel participant, BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final userService = UserService();
      final UserModel? member = await userService.getUserById(participant.userId);
      
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
      
      if (mounted) {
        setState(() {
          _streamKey++;
        });
      }
      
    } catch (error) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load member profile'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

Future<void> _togglePaymentStatus(
  ParticipantModel participant,
  BuildContext context,
) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final contributionProvider = context.read<ContributionProvider>();
  final errorColor = AppColors.error(context);
  final warningColor = AppColors.warning(context);
  
  final programId = widget.program.programId;
  final communityId = widget.program.communityId;
  final isMonthlyProgram = widget.program.isMonthlyPaymentProgram;
  final suggestedAmount = widget.program.suggestedContribution ?? 0.0;

  if (!mounted) return;

  setState(() => _updatingParticipants[participant.userId] = true);

  try {
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) return;

    if (suggestedAmount <= 0) {
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

    contributionProvider.clearCacheForUser(programId, participant.userId);

    final contributions = await contributionProvider.getUserContributionsForProgram(
      programId,
      participant.userId,
      forceRefresh: true,
    );

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

      final monthlyContributions = contributions.where(
        (c) => c.isMonthlyContribution && c.monthId == _selectedMonth,
      ).toList();

      final totalPaid = monthlyContributions.fold<double>(
        0.0,
        (sum, c) => sum + c.amount,
      );

      if (totalPaid >= suggestedAmount) {
        await _removeContributions(
          contributionProvider: contributionProvider,
          scaffoldMessenger: scaffoldMessenger,
          context: context,
          programId: programId,
          userId: participant.userId,
          participantName: participant.userName,
          monthId: _selectedMonth,
          isMonthlyProgram: true,
          reason: totalPaid > suggestedAmount 
            ? 'Marking as pending: Overpaid for ${_formatMonthDisplay(_selectedMonth!)}' 
            : 'Marking as pending: Fully paid for ${_formatMonthDisplay(_selectedMonth!)}',
        );
      } else {
        final remaining = suggestedAmount - totalPaid;
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

    final nonMonthlyContributions = contributions.where((c) => !c.isMonthlyContribution).toList();
    final totalPaid = nonMonthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);

    if (totalPaid >= suggestedAmount) {
      await _removeContributions(
        contributionProvider: contributionProvider,
        scaffoldMessenger: scaffoldMessenger,
        context: context,
        programId: programId,
        userId: participant.userId,
        participantName: participant.userName,
        monthId: null,
        isMonthlyProgram: false,
        reason: totalPaid > suggestedAmount 
          ? 'Marking as pending: Overpaid' 
          : 'Marking as pending: Fully paid',
      );
    } else {
      final remaining = suggestedAmount - totalPaid;
      await _createContribution(
        contributionProvider: contributionProvider,
        scaffoldMessenger: scaffoldMessenger,
        programId: programId,
        communityId: communityId,
        userId: participant.userId,
        participantName: participant.userName,
        amount: remaining,
        monthId: null,
        isMonthlyProgram: false,
      );
    }

  } catch (error) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Failed to update payment status'),
        backgroundColor: errorColor,
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _updatingParticipants.remove(participant.userId);
        _streamKey++;
      });
    }
  }
}

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
    
    final contribution = ContributionModel(
      contributionId: contributionId,
      programId: programId,
      userId: userId,
      contributorName: participantName,
      communityId: communityId,
      amount: amount,
      paymentMethod: 'cash',
      isMonthlyContribution: isMonthlyProgram,
      monthId: monthId,
      createdAt: Timestamp.now(),
    );
    
    await contributionProvider.addContribution(contribution);
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
    
  } catch (error) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Failed to create contribution'),
        backgroundColor: Colors.red,
      ),
    );
    rethrow;
  }
}

Future<void> _removeContributions({
  required ContributionProvider contributionProvider,
  required ScaffoldMessengerState scaffoldMessenger,
  required BuildContext context,
  required String programId,
  required String userId,
  required String participantName,
  required String? monthId,
  required bool isMonthlyProgram,
  required String reason,
}) async {
  try {
    final contributions = await contributionProvider.getUserContributionsForProgram(
      programId,
      userId,
      forceRefresh: true,
    );
    
    List<String> contributionsToDelete = [];
    
    if (isMonthlyProgram && monthId != null) {
      contributionsToDelete = contributions
          .where((c) => c.isMonthlyContribution && c.monthId == monthId)
          .map((c) => c.contributionId)
          .toList();
    } else {
      contributionsToDelete = contributions
          .where((c) => !c.isMonthlyContribution)
          .map((c) => c.contributionId)
          .toList();
    }
    
    for (final contributionId in contributionsToDelete) {
      await contributionProvider.deleteContribution(contributionId, reason);
    }
    
    contributionProvider.clearCacheForUser(programId, userId);
    
    String message = isMonthlyProgram && monthId != null
        ? 'Marked $participantName as pending for ${_formatMonthDisplay(monthId)}'
        : 'Marked $participantName as pending';
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
    
  } catch (error) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Failed to update payment status'),
        backgroundColor: Colors.red,
      ),
    );
    rethrow;
  }
}

  void _showRemoveConfirmation(ParticipantModel participant, BuildContext context) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Remove Participant?',
      message: 'Are you sure you want to remove ${participant.userName} from this program?',
      confirmLabel: 'Remove',
      isDestructive: true,
      icon: Icons.person_remove_rounded,
    );

    if (result == true) {
      _removeParticipant(participant, context);
    }
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
      
      final contributions = await contributionProvider.getUserContributionsForProgram(
        programId,
        userId,
        forceRefresh: true,
      );
      
      if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
        final monthlyContributions = contributions
            .where((c) => c.isMonthlyContribution && c.monthId == _selectedMonth)
            .toList();
        
        final totalPaid = monthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        return totalPaid >= suggestedAmount;
      } else {
        final nonMonthlyContributions = contributions
            .where((c) => !c.isMonthlyContribution)
            .toList();
        
        final totalPaid = nonMonthlyContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        return totalPaid >= suggestedAmount;
      }
    } catch (error) {
      return false;
    }
  }

  Future<String?> _getPaymentSubtitleWithRealData(ParticipantModel participant) async {
    try {
      final contributionProvider = context.read<ContributionProvider>();
      final suggestedAmount = widget.program.suggestedContribution ?? 0.0;
      
      if (suggestedAmount <= 0) {
        return widget.program.isMonthlyPaymentProgram && _selectedMonth != null
            ? 'For ${_formatMonthDisplay(_selectedMonth!)}'
            : null;
      }
      
      final contributions = await contributionProvider.getUserContributionsForProgram(
        widget.program.programId,
        participant.userId,
        forceRefresh: true,
      );
      
      double totalPaid;
      
      if (widget.program.isMonthlyPaymentProgram && _selectedMonth != null) {
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
      return null;
    }
  }
}

class _SliverPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _SliverPinnedHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _SliverPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.maxExtent != maxExtent ||
        oldDelegate.minExtent != minExtent;
  }
}
