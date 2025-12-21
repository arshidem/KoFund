// lib/features/issues/screens/report_issue_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/issues/providers/issue_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/issues/screens/my_issues_screen.dart'; // Add this import
// Add this import at the top
import 'package:kofund/features/auth/providers/app_auth_provider.dart';

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

  Widget _buildIssueTypeChip(Map<String, dynamic> type) {
    final isSelected = _selectedIssueType == type['value'];
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type['icon'], size: 18),
          const SizedBox(width: 6),
          Text(type['label']),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedIssueType = type['value']);
      },
      backgroundColor: AppColors.card(context),
      selectedColor: AppColors.primary(context).withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

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
    _showSuccessDialog(issueId);
    
  } catch (e) {
    SnackbarHelper.showError(context, 'Failed to submit issue: $e');
  }
}

  void _showSuccessDialog(String issueId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Issue Submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 60,
              color: AppColors.success(context),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for reporting this issue!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Issue ID: ${issueId.substring(0, 8)}...',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Our developers will review it and update you soon.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearForm();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
          toolbarHeight: 80, // Set your desired height here (default is 56)

        title: const Text(
          'Report Issue',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.background(context),
          systemNavigationBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  color: AppColors.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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

                // Issue Type Selection
                Text(
                  'Issue Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _issueTypes.map(_buildIssueTypeChip).toList(),
                ),

                const SizedBox(height: 24),

                // Issue Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Issue Title *',
                    labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                    hintText: 'Briefly describe the issue',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
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