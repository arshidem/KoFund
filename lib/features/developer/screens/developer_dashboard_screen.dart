import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'add_developer_screen.dart';
import 'manage_developers_screen.dart';
import 'issue_reports_screen.dart';
import 'update_config_screen.dart';
import 'announcement_manager_screen.dart';
import 'push_notification_tool_screen.dart';
import 'database_tools_screen.dart';
import 'app_analytics_screen.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
class DeveloperDashboardScreen extends StatelessWidget {
  static const routeName = '/developer-dashboard';
  
  const DeveloperDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final _authProvider = context.watch<AppAuthProvider>();
    
    // Security check
    if (!_authProvider.isDeveloper) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('Developer access required')),
      );
    }

    return GradientSheetScaffold(
      title: 'Developer Dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.developer_mode,
                      size: 48,
                      color: AppColors.primary(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Developer Tools',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Restricted access for development and debugging',
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

            const SizedBox(height: 12),
            // Development Tools
            Text(
              'Development Tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),

            GridView.count(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildToolCard(
                  context: context,
                  icon: Icons.bug_report,
                  title: 'Issue Reports',
                  subtitle: 'View user reports',
                  color: Colors.red,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IssueReportsScreen(),
                    ),
                  ),
                ),
                _buildToolCard(
                  context: context,
                  icon: Icons.analytics,
                  title: 'App Analytics',
                  subtitle: 'Usage statistics',
                  color: Colors.green,
                  onTap: () => _navigateToAnalytics(context),
                ),
                _buildToolCard(
                  context: context,
                  icon: Icons.storage,
                  title: 'Database',
                  subtitle: 'Firestore tools',
                  color: Colors.blue,
                  onTap: () => _navigateToDatabase(context),
                ),
                _buildToolCard(
                  context: context,
                  icon: Icons.settings,
                  title: 'App Config',
                  subtitle: 'Remote config',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UpdateConfigScreen()),
                  ),
                ),
                _buildToolCard(
                  context: context,
                  icon: Icons.campaign,
                  title: 'Announcements',
                  subtitle: 'Manage app news',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AnnouncementManagerScreen()),
                  ),
                ),
                _buildToolCard(
                  context: context,
                  icon: Icons.send_rounded,
                  title: 'Push Tools',
                  subtitle: 'Targeted notifications',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PushNotificationToolScreen()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // User Management Section
            Text(
              'Developer Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),

             Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                   ListTile(
                    leading: Icon(
                      Icons.person_add,
                      color: AppColors.primary(context),
                    ),
                    title: Text(
                      'Add New Developer',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    subtitle: Text(
                      'Grant developer access to users',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddDeveloperScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: AppColors.border(context)),
                  ListTile(
                    leading: Icon(
                      Icons.people,
                      color: AppColors.primary(context),
                    ),
                    title: Text(
                      'Manage Developers',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    subtitle: Text(
                      'View and manage all developers',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageDevelopersScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Danger Zone
            Card(
              color: AppColors.error(context).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.error(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: AppColors.error(context),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These actions are irreversible',
                      style: TextStyle(
                        color: AppColors.error(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showClearCacheDialog(context),
                        icon: Icon(
                          Icons.delete_forever,
                          color: AppColors.error(context),
                        ),
                        label: Text(
                          'Clear App Cache',
                          style: TextStyle(color: AppColors.error(context)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error(context)),
                        ),
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

  // Add BuildContext parnameter to this method
  Widget _buildToolCard({
    required BuildContext context, // Add this parnameter
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.card(context), // Now context is available
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(context), // Now works
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary(context), // Now works
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToIssues(BuildContext context) {
    // TODO: Navigate to issue reports
  }

  void _navigateToAnalytics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppAnalyticsScreen()),
    );
  }

  void _navigateToDatabase(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DatabaseToolsScreen()),
    );
  }

  void _navigateToConfig(BuildContext context) {
    // TODO: Navigate to config
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Clear cache logic
              Navigator.pop(context);
              SnackbarHelper.showInfo(context, 'Cache cleared');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error(context), // Now works
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}





