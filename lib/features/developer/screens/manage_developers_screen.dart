import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class ManageDevelopersScreen extends StatefulWidget {
  const ManageDevelopersScreen({super.key});

  @override
  State<ManageDevelopersScreen> createState() => _ManageDevelopersScreenState();
}

class _ManageDevelopersScreenState extends State<ManageDevelopersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _developers = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadDevelopers();
  }

  /// Safely convert a Firestore field that may be a Timestamp, int (ms), or null.
  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Future<void> _loadDevelopers({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      HapticHelper.light();
    }

    try {
      final query = await _firestore
          .collection('users')
          .where('isDeveloper', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        _developers = query.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'email': data['email'] ?? 'No email',
            'name': data['displayName'] ?? data['name'] ?? 'Unknown',
            'phone': data['phoneNumber'] ?? data['phone'] ?? '',
            'isAdmin': data['isAdmin'] ?? false,
            'createdAt': _toDate(data['createdAt']),
            'updatedAt': _toDate(data['updatedAt']),
            'lastActive': _toDate(data['lastActive']),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackbarHelper.showError(context, 'Error loading developers: $e');
    }
  }

  Future<void> _removeDeveloper(String userId, String email) async {
    final authProvider = context.read<AppAuthProvider>();

    // Prevent removing yourself
    if (userId == authProvider.user?.uid) {
      SnackbarHelper.showError(context, 'You cannot remove yourself as developer');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Developer'),
        content: Text('Are you sure you want to remove developer access from $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performRemoveDeveloper(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRemoveDeveloper(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeveloper': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadDevelopers();
      if (!mounted) return;

      SnackbarHelper.showSuccess(context, 'Developer access removed');
    } catch (e) {
      SnackbarHelper.showError(context, 'Error: $e');
    }
  }

  void _showDeveloperDetails(Map<String, dynamic> developer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Name', developer['name']),
              _buildDetailItem('Email', developer['email']),
              if ((developer['phone'] as String).isNotEmpty)
                _buildDetailItem('Phone', developer['phone']),
              _buildDetailItem('User ID', developer['id']),
              _buildDetailItem(
                'Community Admin',
                developer['isAdmin'] ? 'Yes' : 'No',
              ),
              if (developer['createdAt'] != null)
                _buildDetailItem(
                  'Joined',
                  DateFormat('dd MMM yyyy').format(developer['createdAt'] as DateTime),
                ),
              if (developer['lastActive'] != null)
                _buildDetailItem(
                  'Last Active',
                  DateFormat('dd MMM yyyy - hh:mm a').format(developer['lastActive'] as DateTime),
                ),
            ],
          ),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(Map<String, dynamic> developer) {
    final authProvider = context.read<AppAuthProvider>();
    final isCurrentUser = developer['id'] == authProvider.user?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary(context).withValues(alpha: 0.1),
          child: Icon(
            Icons.person,
            color: AppColors.primary(context),
          ),
        ),
        title: Text(
          developer['name'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              developer['email'],
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
            if (developer['createdAt'] != null)
              Text(
                'Added: ${DateFormat('dd MMM yyyy').format(developer['createdAt'] as DateTime)}',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 10,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Admin badge
            if (developer['isAdmin'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // Current user badge
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // Actions menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textSecondary(context),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                if (!isCurrentUser) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove Access', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
              onSelected: (value) {
                if (value == 'details') {
                  _showDeveloperDetails(developer);
                } else if (value == 'remove') {
                  _removeDeveloper(developer['id'], developer['email']);
                }
              },
            ),
          ],
        ),
        onTap: () => _showDeveloperDetails(developer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();

    if (!authProvider.isDeveloper) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: Text('Access denied')),
      );
    }

    return GradientSheetScaffold(
      title: 'Manage Developers',
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: const [],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () => _loadDevelopers(silent: true),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverToBoxAdapter(
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
                                      _developers.length.toString(),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary(context),
                                      ),
                                    ),
                                    Text(
                                      'Total Developers',
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
                                      _developers
                                          .where((d) => d['isAdmin'] == true)
                                          .length
                                          .toString(),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    Text(
                                      'Community Admins',
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

                        // Developers List header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Developers List',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Chip(
                              label: Text('${_developers.length} users'),
                              backgroundColor: AppColors.primary(context).withValues(alpha: 0.1),
                              labelStyle: TextStyle(
                                color: AppColors.primary(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_developers.isEmpty)
                          Card(
                            color: AppColors.card(context),
                            child: const Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No Developers Found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add developers from the Add Developer screen',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._developers.map(_buildDeveloperCard),

                        const SizedBox(height: 24),

                        // Info card
                        Card(
                          color: AppColors.surface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.primary(context),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Information',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Developers have access to developer tools\n'
                                  '• You cannot remove yourself as developer\n'
                                  '• Community Admins can manage community\n'
                                  '• Tap on a developer to view details\n'
                                  '• Use menu (...) for more actions',
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
