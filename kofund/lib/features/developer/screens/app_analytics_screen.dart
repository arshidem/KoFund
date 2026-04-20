import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/skeleton/app_analytics_skeleton.dart';

class AppAnalyticsScreen extends StatefulWidget {
  const AppAnalyticsScreen({super.key});

  @override
  State<AppAnalyticsScreen> createState() => _AppAnalyticsScreenState();
}

class _AppAnalyticsScreenState extends State<AppAnalyticsScreen> {
  final _fs = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _error;

  // Overview stats
  int _totalUsers = 0;
  int _totalCommunities = 0;
  int _totalPrograms = 0;
  int _totalContributions = 0;
  int _totalExpenses = 0;
  int _totalNotifications = 0;
  int _totalParticipants = 0;
  int _totalPolls = 0;

  // User breakdown
  int _approvedUsers = 0;
  int _pendingUsers = 0;
  int _adminUsers = 0;
  int _developerUsers = 0;
  int _virtualUsers = 0;

  // Program breakdown
  int _activePrograms = 0;
  int _completedPrograms = 0;

  // Contribution breakdown
  int _pendingContributions = 0;
  int _confirmedContributions = 0;
  int _deletedContributions = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Run all counts in parallel for speed
      final results = await Future.wait([
        // Overview counts (0-7)
        _fs.collection('users').count().get(),
        _fs.collection('communities').count().get(),
        _fs.collection('programs').count().get(),
        _fs.collection('contributions').count().get(),
        _fs.collection('expenses').count().get(),
        _fs.collection('notifications').count().get(),
        _fs.collection('participants').count().get(),
        _fs.collection('polls').count().get(),

        // User breakdowns (8-12)
        _fs.collection('users').where('isApproved', isEqualTo: true).count().get(),
        _fs.collection('users').where('isApproved', isEqualTo: false).count().get(),
        _fs.collection('users').where('isAdmin', isEqualTo: true).count().get(),
        _fs.collection('users').where('isDeveloper', isEqualTo: true).count().get(),
        _fs.collection('users').where('isVirtualUser', isEqualTo: true).count().get(),

        // Program breakdowns (13-14)
        _fs.collection('programs').where('status', isEqualTo: 'active').count().get(),
        _fs.collection('programs').where('status', isEqualTo: 'completed').count().get(),

        // Contribution breakdowns (15-17)
        _fs.collection('contributions').where('status', isEqualTo: 'pending').count().get(),
        _fs.collection('contributions').where('status', isEqualTo: 'confirmed').count().get(),
        _fs.collection('deleted_contributions').count().get(),
      ]);

      if (mounted) {
        setState(() {
          _totalUsers = results[0].count ?? 0;
          _totalCommunities = results[1].count ?? 0;
          _totalPrograms = results[2].count ?? 0;
          _totalContributions = results[3].count ?? 0;
          _totalExpenses = results[4].count ?? 0;
          _totalNotifications = results[5].count ?? 0;
          _totalParticipants = results[6].count ?? 0;
          _totalPolls = results[7].count ?? 0;

          _approvedUsers = results[8].count ?? 0;
          _pendingUsers = results[9].count ?? 0;
          _adminUsers = results[10].count ?? 0;
          _developerUsers = results[11].count ?? 0;
          _virtualUsers = results[12].count ?? 0;

          _activePrograms = results[13].count ?? 0;
          _completedPrograms = results[14].count ?? 0;

          _pendingContributions = results[15].count ?? 0;
          _confirmedContributions = results[16].count ?? 0;
          _deletedContributions = results[17].count ?? 0;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'App Analytics',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: const [],
      body: _isLoading
          ? const AppAnalyticsSkeleton()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error(context)),
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: AppColors.error(context), fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadAnalytics, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: _loadAnalytics,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // — Overview Grid —
                        _buildSectionHeader(context, icon: Icons.dashboard_rounded, title: 'Overview', color: Colors.blue),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _buildStatCard(context, 'Users', _totalUsers, Icons.people_rounded, Colors.blue),
                            _buildStatCard(context, 'Communities', _totalCommunities, Icons.groups_rounded, Colors.purple),
                            _buildStatCard(context, 'Programs', _totalPrograms, Icons.account_balance_wallet_rounded, Colors.green),
                            _buildStatCard(context, 'Contributions', _totalContributions, Icons.payments_rounded, Colors.orange),
                            _buildStatCard(context, 'Expenses', _totalExpenses, Icons.receipt_long_rounded, Colors.red),
                            _buildStatCard(context, 'Participants', _totalParticipants, Icons.how_to_reg_rounded, Colors.teal),
                            _buildStatCard(context, 'Notifications', _totalNotifications, Icons.notifications_rounded, Colors.amber),
                            _buildStatCard(context, 'Polls', _totalPolls, Icons.poll_rounded, Colors.indigo),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // — User Breakdown —
                        _buildSectionHeader(context, icon: Icons.people_alt_rounded, title: 'User Breakdown', color: Colors.blue),
                        const SizedBox(height: 12),
                        Card(
                          color: AppColors.card(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildBarRow(context, 'Approved', _approvedUsers, _totalUsers, Colors.green),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Pending', _pendingUsers, _totalUsers, Colors.orange),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Admins', _adminUsers, _totalUsers, Colors.blue),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Developers', _developerUsers, _totalUsers, Colors.purple),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Virtual Users', _virtualUsers, _totalUsers, Colors.teal),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // — Program Breakdown —
                        _buildSectionHeader(context, icon: Icons.account_balance_wallet_rounded, title: 'Program Breakdown', color: Colors.green),
                        const SizedBox(height: 12),
                        Card(
                          color: AppColors.card(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildBarRow(context, 'Active', _activePrograms, _totalPrograms, Colors.green),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Completed', _completedPrograms, _totalPrograms, Colors.blue),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Other', _totalPrograms - _activePrograms - _completedPrograms, _totalPrograms, Colors.grey),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // — Contribution Breakdown —
                        _buildSectionHeader(context, icon: Icons.payments_rounded, title: 'Contribution Breakdown', color: Colors.orange),
                        const SizedBox(height: 12),
                        Card(
                          color: AppColors.card(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildBarRow(context, 'Confirmed', _confirmedContributions, _totalContributions, Colors.green),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Pending', _pendingContributions, _totalContributions, Colors.orange),
                                const SizedBox(height: 12),
                                _buildBarRow(context, 'Deleted', _deletedContributions, _totalContributions + _deletedContributions, Colors.red),
                              ],
                            ),
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

  Widget _buildSectionHeader(BuildContext context, {required IconData icon, required String title, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, int count, IconData icon, Color color) {
    return Card(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarRow(BuildContext context, String label, int value, int total, Color color) {
    final ratio = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context)),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              child: Text(
                '$pct%',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context)),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
