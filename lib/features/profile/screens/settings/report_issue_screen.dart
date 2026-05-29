// lib/features/issues/screens/report_issue_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/issues/providers/issue_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/issues/screens/my_issues_screen.dart'; // Add this import
// Add this import at the top
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_styles.dart';

import 'package:kofund/core/utils/dialog_helper.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();

  String _selectedIssueType = 'bug';
  bool _includeScreenshot = false;

  final List<Map<String, dynamic>> _issueTypes = [
    {'value': 'bug', 'label': 'Bug Report', 'icon': Icons.bug_report},
    {'value': 'feature', 'label': 'Feature Request', 'icon': Icons.lightbulb},
    {'value': 'ui', 'label': 'UI/UX Issue', 'icon': Icons.palette},
    {'value': 'performance', 'label': 'Performance', 'icon': Icons.speed},
    {'value': 'security', 'label': 'Security Concern', 'icon': Icons.security},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];



Future<void> _submitIssue() async {
  if (!_formKey.currentState!.validate()) return;

  final issueProvider = Provider.of<IssueProvider>(context, listen: false);
  final authProvider = Provider.of<AppAuthProvider>(context, listen: false); // Add this

  // Check if user is logged in
  if (authProvider.user == null) {
    SnackbarHelper.showError(context, 'Please log in to report an issue');
    return;
  }

  try {
    final issueId = await issueProvider.createIssue(
      title: _titleController.text,
      description: _descriptionController.text,
      type: _selectedIssueType,
      stepsToReproduce: _stepsController.text.isNotEmpty 
          ? _stepsController.text 
          : null,
      screenshotUrl: _includeScreenshot ? 'todo://upload-screenshot' : null,
      userId: authProvider.user!.uid, // Add this line
    );

    // Show success dialog
    if (!mounted) return;
    _showSuccessDialog(issueId);
    
  } catch (e) {
    if (!mounted) return;
    SnackbarHelper.showError(context, 'Failed to submit issue: $e');
  }
}

  void _showSuccessDialog(String issueId) {
    DialogHelper.showConfirmationDialog(
      context,
      title: 'Issue Submitted',
      message: 'Thank you for reporting this issue!\n\nIssue ID: ${issueId.substring(0, 8)}...\n\nOur developers will review it and update you soon.',
      confirmLabel: 'OK',
      cancelLabel: '',
      icon: Icons.check_circle,
    ).then((_) {
      if (mounted) {
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedIssueType = 'bug';
      _includeScreenshot = false;
    });
    _titleController.clear();
    _descriptionController.clear();
    _stepsController.clear();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issueProvider = Provider.of<IssueProvider>(context);

    return GradientSheetScaffold(
      title: 'Report Issue',
      body: SingleChildScrollView(
        child: Padding(
          padding: AppStyles.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  color: AppColors.card(context),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.report_problem,
                          size: 48,
                          color: AppColors.primary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Help Us Improve',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Report bugs, suggest features, or share feedback to help make Kofund better.',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Issue type Selection
                Text(
                  'Issue type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
                  ),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    color: AppColors.card(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            _issueTypes.firstWhere((t) => t['value'] == _selectedIssueType)['icon'],
                            color: AppColors.primary(context),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _issueTypes.firstWhere((t) => t['value'] == _selectedIssueType)['label'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textTertiary(context),
                          ),
                        ],
                      ),
                    ),
                    onSelected: (value) {
                      setState(() => _selectedIssueType = value);
                    },
                    itemBuilder: (BuildContext context) => _issueTypes.map((type) {
                      return PopupMenuItem<String>(
                        value: type['value'],
                        height: 48,
                        child: Row(
                          children: [
                            Icon(
                              type['icon'],
                              color: _selectedIssueType == type['value'] 
                                  ? AppColors.primary(context) 
                                  : AppColors.textSecondary(context),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              type['label'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedIssueType == type['value'] 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: _selectedIssueType == type['value'] 
                                    ? AppColors.primary(context) 
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // Issue Ttitle
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Issue Title *',
                    labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                    hintText: 'Briefly describe the issue',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border(context).withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border(context).withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.primary(context), width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.card(context),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    if (value.length < 5) {
                      return 'Title must be at least 5 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                    hintText: 'Describe the issue in detail...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border(context).withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border(context).withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.primary(context), width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.card(context),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    if (value.length < 20) {
                      return 'Description must be at least 20 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Steps to Reproduce
                TextFormField(
                  controller: _stepsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Steps to Reproduce (Optional)',
                    labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                    hintText: '1. Go to...\n2. Click on...\n3. See error...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border(context).withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border(context).withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.primary(context), width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.card(context),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 16),

                // // Screenshot Option
                // Card(
                //   color: AppColors.card(context),
                //   shape: RoundedRectangleBorder(
                //     borderRadius: BorderRadius.circular(12),
                //   ),
                //   child: SwitchListTile(
                //     title: Text(
                //       'Include Screenshot',
                //       style: TextStyle(
                //         color: AppColors.textPrimary(context),
                //         fontWeight: FontWeight.w500,
                //       ),
                //     ),
                //     subtitle: Text(
                //       'Attach a screenshot if available',
                //       style: TextStyle(
                //         color: AppColors.textSecondary(context),
                //         fontSize: 12,
                //       ),
                //     ),
                //     value: _includeScreenshot,
                //     onChanged: (value) => setState(() => _includeScreenshot = value),
                //     activeColor: AppColors.primary(context),
                //   ),
                // ),

                // const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: issueProvider.isLoading ? null : _submitIssue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: issueProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Issue Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Clear Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: issueProvider.isLoading ? null : _clearForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.border(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Clear Form',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                // Error Message
                if (issueProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      issueProvider.error!,
                      style: TextStyle(
                        color: AppColors.error(context),
                        fontSize: 14,
                      ),
                    ),
                  ),
const SizedBox(height: 16),

// View My Issues Card
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyIssuesScreen(),
      ),
    );
  },
  child: Card(
    color: AppColors.card(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.list_alt,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View My Reported Issues',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track status of all your submitted issues',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.textTertiary(context),
          ),
        ],
      ),
    ),
  ),
),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}






