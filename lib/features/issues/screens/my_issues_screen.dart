// lib/features/issues/screens/my_issues_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/issues/providers/issue_provider.dart';
import 'package:kofund/features/issues/models/issue_model.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/constants/app_dimensions.dart';

class MyIssuesScreen extends StatefulWidget {
  const MyIssuesScreen({super.key});

  @override
  State<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends State<MyIssuesScreen> {
  String _selectedFilter = 'all';
  final Map<String, String> _filterLabels = {
    'all': 'All Issues',
    'pending': 'Pending',
    'in-progress': 'In Progress',
    'resolved': 'Resolved',
    'closed': 'Closed',
  };

  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'in-progress': Colors.blue,
    'resolved': Colors.green,
    'closed': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyIssues();
    });
  }

  Future<void> _loadMyIssues() async {
    final authProvider = context.read<AppAuthProvider>();
    final issueProvider = context.read<IssueProvider>();
    
    if (authProvider.user != null) {
      await issueProvider.loadMyIssues(authProvider.user!.uid);
    }
  }

  List<IssueModel> _getFilteredIssues(List<IssueModel> allIssues) {
    if (_selectedFilter == 'all') return allIssues;
    return allIssues.where((issue) => issue.status == _selectedFilter).toList();
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColors[status]!.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColors[status]!),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _statusColors[status],
        ),
      ),
    );
  }

  Widget _buildTeventTypeChip(String type) {
    final typeIcons = {
      'bug': Icons.bug_report,
      'feature': Icons.lightbulb,
      'ui': Icons.palette,
      'performance': Icons.speed,
      'security': Icons.security,
      'other': Icons.more_horiz,
    };

    final typeColors = {
      'bug': Colors.red,
      'feature': Colors.purple,
      'ui': Colors.pink,
      'performance': Colors.teal,
      'security': Colors.amber,
      'other': Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: typeColors[type]!.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(typeIcons[type] ?? Icons.error, size: 12, color: typeColors[type]),
          const SizedBox(width: 4),
          Text(
            type.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: typeColors[type],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(IssueModel issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _statusColors[issue.status]!.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getIssueIcon(issue.type),
            color: _statusColors[issue.status],
            size: 24,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.title.length > 60 
                  ? '${issue.title.substring(0, 60)}...' 
                  : issue.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip(issue.status),
                const SizedBox(width: 8),
                _buildTeventTypeChip(issue.type),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              issue.description.length > 80
                  ? '${issue.description.substring(0, 80)}...'
                  : issue.description,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: AppColors.textTertiary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(issue.createdAt.toDate()),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(context),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: AppColors.textTertiary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  _getTimeAgo(issue.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ],
            ),
            if (issue.assignedDeveloperName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 12,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${issue.assignedDeveloperName!}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () => _showIssueDetails(issue),
      ),
    );
  }

  IconData _getIssueIcon(String type) {
    switch (type) {
      case 'bug': return Icons.bug_report;
      case 'feature': return Icons.lightbulb;
      case 'ui': return Icons.palette;
      case 'performance': return Icons.speed;
      case 'security': return Icons.security;
      default: return Icons.error;
    }
  }

// Change this method signature:
String _getTimeAgo(Timestamp timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp.toDate());
  
  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  }
  return 'Just now';
}
  void _showIssueDetails(IssueModel issue) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header with title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusColors[issue.status]!.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIssueIcon(issue.type),
                      color: _statusColors[issue.status],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context).withValues(alpha: 0.4),
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          issue.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & type Chips
                    Row(
                      children: [
                        _buildStatusChip(issue.status),
                        const SizedBox(width: 10),
                        _buildTeventTypeChip(issue.type),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description Section
                    _buildSectionTtitle('DESCRIPTION'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        issue.description,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                    
                    // Steps to Reproduce
                    if (issue.stepsToReproduce != null && issue.stepsToReproduce!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTtitle('STEPS TO REPRODUCE'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          issue.stepsToReproduce!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary(context).withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    _buildSectionTtitle('ISSUE INFORMATION'),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.fingerprint, 'Issue ID', '#${issue.id.substring(0, 8)}'),
                    _buildDetailRow(Icons.calendar_month, 'Reported Date', DateFormat('MMM dd, yyyy').format(issue.createdAt.toDate())),
                    _buildDetailRow(Icons.history, 'Relative Time', _getTimeAgo(issue.createdAt)),
                    _buildDetailRow(Icons.info_outline, 'App Version', 'v${issue.appVersion}'),
                    _buildDetailRow(Icons.devices, 'Platform', issue.platform.toUpperCase()),
                    
                    if (issue.assignedDeveloperName != null)
                      _buildDetailRow(Icons.engineering_rounded, 'Assigned To', issue.assignedDeveloperName!, valueColor: Colors.blue),

                    // Resolution Notes
                    if (issue.resolutionNotes != null && issue.resolutionNotes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTtitle('RESOLUTION NOTES'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                issue.resolutionNotes!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTtitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.textTertiary(context),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary(context).withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value) {
    final isSelected = _selectedFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          _filterLabels[value]!,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFilter = value);
          }
        },
        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        selectedColor: AppColors.primary(context),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.transparent : AppColors.border(context).withValues(alpha: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final issueProvider = context.watch<IssueProvider>();
    
    if (authProvider.user == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: Text('Please log in to view your issues')),
      );
    }

    final filteredIssues = _getFilteredIssues(issueProvider.myIssues);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context, issueProvider),
          ];
        },
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async => _loadMyIssues(),
            ),
            
            // Filter Chips Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'pending', 'in-progress', 'resolved', 'closed']
                        .map((filter) => _buildFilterChip(filter))
                        .toList(),
                  ),
                ),
              ),
            ),

            // Issues List Content
            _buildIssuesListSliver(issueProvider, filteredIssues),
            
            // Bottom Padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, IssueProvider issueProvider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    
    return SliverAppBar(
      expandedHeight: 190,
      toolbarHeight: 60,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: AppColors.background(context),
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back, 
          color: isDark ? Colors.white : AppColors.textPrimary(context),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          final double maxHeight = 190.0 + statusBarHeight;
          final double collapsedHeight = 60.0 + (72 + 18) + statusBarHeight;
          
          final double progress = ((top - collapsedHeight) / (maxHeight - collapsedHeight)).clamp(0.0, 1.0);
          final double titleFontSize = 20 + (4 * progress);
          final double titleTop = statusBarHeight + 10 + (25 * progress);
          
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: isDark 
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1A2E2E),
                            Color(0xFF0D1B1A),
                          ],
                        )
                      : null,
                  color: isDark ? null : AppColors.background(context),
                ),
              ),
              
              // Title centered horizontally, but moving vertically
              Positioned(
                top: titleTop,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'My Issues',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary(context),
                      letterSpacing: -0.5 - (0.5 * progress),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(72 + 18),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.screenPaddingHorizontal),
              child: _buildStatsRow(issueProvider),
            ),
            const SizedBox(height: 0),
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(IssueProvider issueProvider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color statsBg = isDark 
        ? Colors.white.withValues(alpha: 0.12) 
        : AppColors.primary(context).withValues(alpha: 0.08);
    final Color statsBorder = isDark 
        ? Colors.white.withValues(alpha: 0.2) 
        : AppColors.primary(context).withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: statsBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statsBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompactStatItem(
            value: issueProvider.myIssues.length.toString(),
            label: 'Total',
          ),
          Container(
            height: 24, 
            width: 1, 
            color: isDark ? Colors.white24 : AppColors.primary(context).withValues(alpha: 0.1),
          ),
          _buildCompactStatItem(
            value: issueProvider.myIssues.where((i) => i.isPending).length.toString(),
            label: 'Pending',
          ),
          Container(
            height: 24, 
            width: 1, 
            color: isDark ? Colors.white24 : AppColors.primary(context).withValues(alpha: 0.1),
          ),
          _buildCompactStatItem(
            value: issueProvider.myIssues.where((i) => i.isResolved).length.toString(),
            label: 'Resolved',
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem({required String value, required String label}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primary(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildIssuesListSliver(IssueProvider issueProvider, List<IssueModel> filteredIssues) {
    if (issueProvider.isLoading && issueProvider.myIssues.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(5, (index) => _buildSkeletonCard()),
          ),
        ),
      );
    }

    if (filteredIssues.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildIssueCard(filteredIssues[index]);
          },
          childCount: filteredIssues.length,
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }



  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Issues Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _selectedFilter == 'all'
                  ? 'You haven\'t reported any issues yet.'
                  : 'No ${_filterLabels[_selectedFilter]!.toLowerCase()} issues found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}





