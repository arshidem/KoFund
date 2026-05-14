// lib/features/developer/screens/issue_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/issues/models/issue_model.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/skeleton/issue_reports_skeleton.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class IssueReportsScreen extends StatefulWidget {
  const IssueReportsScreen({super.key});

  @override
  State<IssueReportsScreen> createState() => _IssueReportsScreenState();
}

class _IssueReportsScreenState extends State<IssueReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // 'all', 'pending', 'in-progress', 'resolved'
  String _selectedSort = 'newest'; // 'newest', 'oldest'

  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'in-progress': Colors.blue,
    'resolved': Colors.green,
    'closed': Colors.grey,
  };

  final Map<String, IconData> _typeIcons = {
    'bug': Icons.bug_report,
    'feature': Icons.lightbulb,
    'ui': Icons.palette,
    'performance': Icons.speed,
    'security': Icons.security,
    'other': Icons.more_horiz,
  };

  Future<void> _updateIssueStatus(String issueId, String newStatus) async {
    try {
      await _firestore.collection('issues').doc(issueId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to update status: $e');
    }
  }

  Future<void> _assignToMe(String issueId) async {
    final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = _authProvider.user;
    
    if (currentUser == null) return;

    try {
      await _firestore.collection('issues').doc(issueId).update({
        'assignedDeveloperId': currentUser.uid,
        'assignedDeveloperName': currentUser.displayName ?? 'Developer',
        'status': 'in-progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to assign issue: $e');
    }
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
        leading: CircleAvatar(
          backgroundColor: _statusColors[issue.status]!.withValues(alpha: 0.1),
          child: Icon(
            _typeIcons[issue.type] ?? Icons.error,
            color: _statusColors[issue.status],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColors[issue.status]!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColors[issue.status]!),
                  ),
                  child: Text(
                    issue.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _statusColors[issue.status],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    issue.type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              issue.description.length > 100 
                  ? '${issue.description.substring(0, 100)}...' 
                  : issue.description,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 12,
                  color: AppColors.textTertiary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  issue.reporterName,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary(context),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: AppColors.textTertiary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd').format(issue.createdAt.toDate()),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ],
            ),
            if (issue.assignedDeveloperName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.engineering,
                    size: 12,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${issue.assignedDeveloperName}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: AppColors.textSecondary(context),
          ),
          itemBuilder: (context) => [
            if (issue.status == 'pending') ...[
              const PopupMenuItem(
                value: 'assign',
                child: Row(
                  children: [
                    Icon(Icons.assignment, size: 18),
                    SizedBox(width: 8),
                    Text('Assign to me'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
            if (issue.status == 'pending' || issue.status == 'in-progress') ...[
              const PopupMenuItem(
                value: 'in-progress',
                child: Row(
                  children: [
                    Icon(Icons.build, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Mark as In Progress'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'resolved',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Mark as Resolved'),
                  ],
                ),
              ),
            ],
            if (issue.status == 'resolved') ...[
              const PopupMenuItem(
                value: 'closed',
                child: Row(
                  children: [
                    Icon(Icons.archive, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Archive (Closed)'),
                  ],
                ),
              ),
            ],
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 18),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'assign') {
              _assignToMe(issue.id);
            } else if (value == 'view') {
              _showIssueDetails(issue);
            } else {
              _updateIssueStatus(issue.id, value);
            }
          },
        ),
        onTap: () => _showIssueDetails(issue),
      ),
    );
  }

  void _showIssueDetails(IssueModel issue) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
            
            // Header
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
                      _typeIcons[issue.type] ?? Icons.error,
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
                          'Report # ${issue.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
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
                    // Status & type
                    Row(
                      children: [
                        _buildBadge(issue.status.toUpperCase(), _statusColors[issue.status]!),
                        const SizedBox(width: 10),
                        _buildBadge(issue.type.toUpperCase(), Colors.blue),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTtitle('DESCRIPTION'),
                    const SizedBox(height: 8),
                    _buildContentBox(issue.description, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03)),

                    if (issue.stepsToReproduce != null && issue.stepsToReproduce!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTtitle('STEPS TO REPRODUCE'),
                      const SizedBox(height: 8),
                      _buildContentBox(issue.stepsToReproduce!, color: Colors.orange.withValues(alpha: 0.05), borderColor: Colors.orange.withValues(alpha: 0.1)),
                    ],

                    const SizedBox(height: 24),
                    _buildSectionTtitle('REPORTER INFORMATION'),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.person_outline, 'Name', issue.reporterName),
                    _buildDetailRow(Icons.email_outlined, 'Email', issue.reporterEmail),
                    _buildDetailRow(Icons.calendar_today_outlined, 'Reported On', DateFormat('MMM dd, yyyy - hh:mm a').format(issue.createdAt.toDate())),
                    
                    const SizedBox(height: 20),
                    _buildSectionTtitle('SYSTEM DETAILS'),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.info_outline, 'App Version', 'v${issue.appVersion}'),
                    _buildDetailRow(Icons.devices, 'Platform', issue.platform.toUpperCase()),
                    
                    if (issue.assignedDeveloperName != null) ...[
                      const SizedBox(height: 20),
                      _buildSectionTtitle('ASSIGNMENT'),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.engineering_rounded, 'Developer', issue.assignedDeveloperName!, valueColor: Colors.blue),
                    ],

                    if (issue.resolutionNotes != null && issue.resolutionNotes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTtitle('RESOLUTION NOTES'),
                      const SizedBox(height: 8),
                      _buildContentBox(issue.resolutionNotes!, color: Colors.green.withValues(alpha: 0.05), borderColor: Colors.green.withValues(alpha: 0.1)),
                    ],
                    
                    const SizedBox(height: 100), // Space for bottom actions
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF162626) : Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  if (issue.status == 'pending') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _assignToMe(issue.id);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.assignment_ind_rounded, size: 20, color: Colors.white),
                        label: const Text('Assign to Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
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

  Widget _buildContentBox(String content, {required Color color, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary(context).withValues(alpha: 0.8),
          height: 1.5,
        ),
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

  @override
  Widget build(BuildContext context) {
    final _authProvider = context.watch<AppAuthProvider>();
    
    if (!_authProvider.isDeveloper) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: Text('Developer access required')),
      );
    }

    return GradientSheetScaffold(
      title: 'Issue Reports',
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list, color: AppColors.textPrimary(context)),
          onPressed: () => _showFilterDialog(context),
          tooltip: 'Filter & Sort',
        ),
      ],
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('issues')
            .where('status', isEqualTo: _selectedFilter == 'all' ? null : _selectedFilter)
            .orderBy('createdAt', descending: _selectedSort == 'newest')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const IssueReportsSkeleton();
          }

          final issues = snapshot.data!.docs
              .map((doc) => IssueModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Card
                Card(
                  color: AppColors.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(
                              issues.length.toString(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary(context),
                              ),
                            ),
                            Text(
                              'Total Issues',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              issues.where((i) => i.status == 'pending').length.toString(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              'Pending',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              issues.where((i) => i.status == 'resolved').length.toString(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'Resolved',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Issues List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Issues List',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Chip(
                      label: Text('${_selectedFilter.toUpperCase()} • ${_selectedSort.toUpperCase()}'),
                      backgroundColor: AppColors.primary(context).withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: AppColors.primary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (issues.isEmpty)
                  Card(
                    color: AppColors.card(context),
                    child: const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 48, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'No Issues Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All issues are resolved! Great work!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...issues.map(_buildIssueCard),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter & Sort'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filter by Status:'),
            Column(
              children: ['all', 'pending', 'in-progress', 'resolved', 'closed'].map((status) {
                return ListTile(
                  title: Text(status.toUpperCase()),
                  leading: Icon(
                    _selectedFilter == status ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: Theme.of(context).primaryColor,
                  ),
                  onTap: () => setState(() => _selectedFilter = status),
                );
              }).toList(),
            ),
            const Divider(),
            const Text('Sort by:'),
            Column(
              children: ['newest', 'oldest'].map((sort) {
                return ListTile(
                  title: Text(sort.toUpperCase()),
                  leading: Icon(
                    _selectedSort == sort ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: Theme.of(context).primaryColor,
                  ),
                  onTap: () => setState(() => _selectedSort = sort),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}





