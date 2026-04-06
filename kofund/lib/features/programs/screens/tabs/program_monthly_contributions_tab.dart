import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../programs/providers/program_provider.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../../features/auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../programs/models/program_model.dart';

class ProgramMonthlyContributionsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramMonthlyContributionsTab({
    super.key,
    required this.program,
  });

  @override
  State<ProgramMonthlyContributionsTab> createState() => _ProgramMonthlyContributionsTabState();
}

class _ProgramMonthlyContributionsTabState extends State<ProgramMonthlyContributionsTab> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  String? _selectedMonth;
  List<String> _availableMonths = [];
  List<Map<String, dynamic>> _participantsWithStatus = [];
  bool _isLoading = true;
  final Map<String, double> _monthlyTotals = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Generate month options
      _availableMonths = _generateMonthOptions();
      
      // Set default month
      final currentMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
      
      if (_availableMonths.contains(currentMonth)) {
        _selectedMonth = currentMonth;
      } else if (_availableMonths.isNotEmpty) {
        _selectedMonth = _availableMonths.first;
      } else {
        _selectedMonth = currentMonth;
        _availableMonths = [currentMonth];
      }
      
      await _loadMonthData();
    } catch (e) {
      debugPrint('❌ Error initializing monthly contributions: $e');
      final currentMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
      _selectedMonth ??= currentMonth;
      if (_availableMonths.isEmpty) _availableMonths = [currentMonth];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> _generateMonthOptions() {
    final Set<String> uniqueMonths = {};
    final now = DateTime.now();
    final startDate = widget.program.firstPaymentDueDate ?? widget.program.programDate ?? DateTime.now();
    
    final start = DateTime(startDate.year, startDate.month, 1);
    final endDate = now.add(const Duration(days: 180));
    
    DateTime current = start;
    while (current.isBefore(endDate) || (current.year == endDate.year && current.month == endDate.month)) {
      final monthStr = "${current.year}-${current.month.toString().padLeft(2, '0')}";
      uniqueMonths.add(monthStr);
      current = DateTime(current.year, current.month + 1, 1);
    }
    
    final months = uniqueMonths.toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  Future<void> _loadMonthData() async {
    if (_selectedMonth == null || !_availableMonths.contains(_selectedMonth)) {
      debugPrint('⚠️ Cannot load data: Invalid selected month $_selectedMonth');
      return;
    }
    
    try {
      final auth = context.read<AppAuthProvider>();
      final programProvider = context.read<ProgramProvider>();
      
      final participants = await programProvider.getParticipantsWithMonthlyStatus(
        widget.program.programId,
        _selectedMonth!,
        auth.user?.communityId ?? '',
      );
      
      final contributionProvider = context.read<ContributionProvider>();
      final monthlyContributions = await contributionProvider.getMonthlyContributionsForProgram(
        widget.program.programId,
        _selectedMonth!,
      );
      
      final total = monthlyContributions.fold(0.0, (sum, c) => sum + c.amount);
      _monthlyTotals[_selectedMonth!] = total;
      
      if (mounted) {
        setState(() {
          _participantsWithStatus = participants;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading month data: $e');
    }
  }

  Future<void> _onRefresh() async {
    try {
      await _loadMonthData();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  String _getMonthDisplayName(String monthId) {
    try {
      final parts = monthId.split('-');
      if (parts.length != 2) return monthId;
      
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      
      if (month < 1 || month > 12) return monthId;
      
      final date = DateTime(year, month, 1);
      final monthName = DateFormat('MMMM').format(date);
      return "$monthName $year";
    } catch (e) {
      return monthId;
    }
  }

  Widget _buildMonthSelector() {
    if (_availableMonths.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, size: 20),
            SizedBox(width: 8),
            Text('No months available'),
          ],
        ),
      );
    }
    
    String? validSelectedMonth = _selectedMonth;
    if (!_availableMonths.contains(validSelectedMonth)) {
      validSelectedMonth = _availableMonths.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedMonth = validSelectedMonth;
          });
        }
      });
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: validSelectedMonth,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _selectedMonth) {
                    setState(() => _selectedMonth = newValue);
                    _loadMonthData();
                  }
                },
                items: _availableMonths.map<DropdownMenuItem<String>>((String monthId) {
                  final isCurrent = monthId == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
                  
                  return DropdownMenuItem<String>(
                    value: monthId,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getMonthDisplayName(monthId),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Current',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.border(context), width: 1),
        ),
      ),
      child: const Row(
        children: [
          // S.No
          SizedBox(
            width: 60,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text(
                'S.No',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          // Name
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                'Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          // Status
          SizedBox(
            width: 100,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          // Actions
          SizedBox(
            width: 120,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                'Actions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(int index, Map<String, dynamic> participant) {
    final hasPaid = participant['hasPaidForMonth'] == true;
    final userName = participant['userName']?.toString() ?? 'Unknown User';
    final userEmail = participant['userEmail']?.toString() ?? '';
    final suggestedAmount = widget.program.suggestedContribution ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: index.isEven 
            ? AppColors.card(context)
            : AppColors.card(context).withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: AppColors.border(context).withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          // S.No
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ),
          
          // Name Column
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${suggestedAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Status Column
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasPaid 
                      ? Colors.green.withValues(alpha: 0.1) 
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasPaid ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPaid ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: hasPaid ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPaid ? 'Paid' : 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasPaid ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Actions Column
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  // Mark as Paid Button
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasPaid ? Colors.grey.shade200 : Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextButton(
                        onPressed: hasPaid ? null : () => _markAsPaid(participant),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          hasPaid ? 'Paid' : 'Mark Paid',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasPaid ? Colors.grey : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // View Details Button
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primary(context).withValues(alpha: 0.3),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () => _viewDetails(participant),
                      icon: Icon(
                        Icons.visibility,
                        size: 16,
                        color: AppColors.primary(context),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_selectedMonth == null || !_availableMonths.contains(_selectedMonth)) {
      return const SizedBox();
    }
    
    final totalAmount = _monthlyTotals[_selectedMonth!] ?? 0;
    final paidCount = _participantsWithStatus.where((p) => p['hasPaidForMonth'] == true).length;
    final totalCount = _participantsWithStatus.length;
final collectionRate = totalCount > 0 ? (paidCount / totalCount) * 100.0 : 0.0;    final targetAmount = totalCount * (widget.program.suggestedContribution ?? 0);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _getMonthDisplayName(_selectedMonth!),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary(context),
            ),
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Collection Progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    '${collectionRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getProgressColor(collectionRate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: targetAmount > 0 ? totalAmount / targetAmount : 0,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(collectionRate)),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${totalAmount.toStringAsFixed(0)} collected',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    '₹${targetAmount.toStringAsFixed(0)} target',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Summary stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.people,
                value: '$paidCount',
                label: 'Paid',
                color: Colors.green,
              ),
              _buildSummaryItem(
                icon: Icons.person_outline,
                value: '${totalCount - paidCount}',
                label: 'Pending',
                color: Colors.orange,
              ),
              _buildSummaryItem(
                icon: Icons.currency_rupee,
                value: '₹${totalAmount.toStringAsFixed(0)}',
                label: 'Collected',
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.blue.shade600;
    if (percentage >= 25) return Colors.orange;
    return Colors.red;
  }

  void _markAsPaid(Map<String, dynamic> participant) {
    // Implement mark as paid functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Text('Mark ${participant['userName']} as paid for ${_getMonthDisplayName(_selectedMonth!)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement payment marking logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Marked ${participant['userName']} as paid')),
              );
              _loadMonthData(); // Refresh data
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _viewDetails(Map<String, dynamic> participant) {
    // Implement view details functionality
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participant Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Name'),
              subtitle: Text(participant['userName']?.toString() ?? 'Unknown'),
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(participant['userEmail']?.toString() ?? 'No email'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Month'),
              subtitle: Text(_getMonthDisplayName(_selectedMonth!)),
            ),
            ListTile(
              leading: const Icon(Icons.payments),
              title: const Text('Status'),
              subtitle: Text(participant['hasPaidForMonth'] == true ? 'Paid' : 'Pending'),
              trailing: Icon(
                participant['hasPaidForMonth'] == true ? Icons.check_circle : Icons.cancel,
                color: participant['hasPaidForMonth'] == true ? Colors.green : Colors.red,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.currency_rupee),
              title: const Text('Amount'),
              subtitle: Text('₹${widget.program.suggestedContribution?.toStringAsFixed(0) ?? '0'}'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primary(context),
        ),
      );
    }

    if (_availableMonths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: AppColors.textSecondary(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No monthly data available',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      enablePullDown: true,
      enablePullUp: false,
      header: ClassicHeader(
        refreshingText: 'Refreshing...',
        completeText: 'Refresh complete',
        failedText: 'Refresh failed',
        idleText: 'Pull down to refresh',
        releaseText: 'Release to refresh',
        refreshingIcon: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
        ),
      ),
      child: Column(
        children: [
          // Month selector
          _buildMonthSelector(),
          
          // Summary card
          _buildSummaryCard(),
          
          const SizedBox(height: 16),
          
          // Table header
          _buildHeaderRow(),
          
          // Table content
          Expanded(
            child: _participantsWithStatus.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textSecondary(context).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No participants found',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _participantsWithStatus.length,
                    itemBuilder: (context, index) {
                      return _buildTableRow(index, _participantsWithStatus[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

