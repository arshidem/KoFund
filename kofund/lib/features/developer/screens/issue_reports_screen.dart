// lib/features/developer/screens/issue_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/issues/models/issue_model.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class IssueReportsScreen extends StatefulWidget {
  const IssueReportsScreen({super.key});

  @override
  State<IssueReportsScreen> createState() => _IssueReportsScreenState();
}

class _IssueReportsScreenState extends State<IssueReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // 'all', 'pending', 'in-progress', 'resolved'
  String _selectedSort = 'newest'; // 'newest', 'oldest'

// Line 24-27: Change from Map<String, String> to Map<String, Color>
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _assignToMe(String issueId) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    
    if (currentUser == null) return;

    try {
      await _firestore.collection('issues').doc(issueId).update({
        'assignedDeveloperId': currentUser.uid,
        'assignedDeveloperName': currentUser.displayName ?? 'Developer',
        'status': 'in-progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign issue: $e')),
      );
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
color: Colors.blue.withValues(alpha: 0.1),                    borderRadius: BorderRadius.circular(12),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Issue Details', style: TextStyle(color: AppColors.textPrimary(context))),
        backgroundColor: AppColors.card(context),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(issue.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColors[issue.status]!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _statusColors[issue.status]!),
                    ),
                    child: Text(issue.status.toUpperCase(), style: TextStyle(color: _statusColors[issue.status], fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Text(issue.type.toUpperCase(), style: const TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
              Text(issue.description, style: TextStyle(color: AppColors.textSecondary(context))),
              if (issue.stepsToReproduce != null) ...[
                const SizedBox(height: 12),
                Text('Steps to Reproduce:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                Text(issue.stepsToReproduce!, style: TextStyle(color: AppColors.textSecondary(context))),
              ],
              const SizedBox(height: 12),
              Divider(color: AppColors.border(context)),
              Text('Reported by:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
              Text('${issue.reporterName} (${issue.reporterEmail})', style: TextStyle(color: AppColors.textSecondary(context))),
              const SizedBox(height: 8),
              Text('Reported on:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
              Text(DateFormat('MMM dd, yyyy - hh:mm a').format(issue.createdAt.toDate()), style: TextStyle(color: AppColors.textSecondary(context))),
              const SizedBox(height: 8),
              Text('App Version:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
              Text(issue.appVersion, style: TextStyle(color: AppColors.textSecondary(context))),
              Text('Platform:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
              Text(issue.platform.toUpperCase(), style: TextStyle(color: AppColors.textSecondary(context))),
              if (issue.assignedDeveloperName != null) ...[
                const SizedBox(height: 8),
                Text('Assigned to:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                Text(issue.assignedDeveloperName!, style: TextStyle(color: Colors.blue)),
              ],
              if (issue.resolutionNotes != null) ...[
                const SizedBox(height: 12),
                Text('Resolution Notes:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                Text(issue.resolutionNotes!, style: TextStyle(color: AppColors.textSecondary(context))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          if (issue.status == 'pending') ...[
            ElevatedButton(
              onPressed: () {
                _assignToMe(issue.id);
                Navigator.pop(context);
              },
              child: const Text('Assign to Me'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    
    if (!authProvider.isDeveloper) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: Text('Developer access required')),
      );
    }

    return GradientSheetScaffold(
      title: 'Issue Reports',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
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
            return const Center(child: CircularProgressIndicator());
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
                return RadioListTile<String>(
                  title: Text(status.toUpperCase()),
                  value: status,
                  groupValue: _selectedFilter,
                  onChanged: (value) => setState(() => _selectedFilter = value!),
                );
              }).toList(),
            ),
            const Divider(),
            const Text('Sort by:'),
            Column(
              children: ['newest', 'oldest'].map((sort) {
                return RadioListTile<String>(
                  title: Text(sort.toUpperCase()),
                  value: sort,
                  groupValue: _selectedSort,
                  onChanged: (value) => setState(() => _selectedSort = value!),
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

