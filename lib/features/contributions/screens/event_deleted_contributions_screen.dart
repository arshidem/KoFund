import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/deleted_contribution_service.dart';
import '../models/deleted_contribution_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/providers/app_auth_provider.dart';

class DeletedContributionsScreen extends StatefulWidget {
  final String eventId;
  final String name;
  
  const DeletedContributionsScreen({
    super.key,
    required this.eventId,
    required this.name,
  });

  @override
  State<DeletedContributionsScreen> createState() => 
      _DeletedContributionsScreenState();
}

class _DeletedContributionsScreenState 
    extends State<DeletedContributionsScreen> {
  final DeletedContributionService _deletedService = DeletedContributionService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool showBackButton = true;
  final Map<String, List<DeletedContributionModel>> _groupedByDate = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<DeletedContributionModel>> _getDeletedContributions(String communityId) {
    return _deletedService.getDeletedContributions(
      eventId: widget.eventId,
      communityId: communityId,
    );
  }

  // Group contributions by date
  Map<String, List<DeletedContributionModel>> _groupContributionsByDate(
    List<DeletedContributionModel> contributions,
  ) {
    final grouped = <String, List<DeletedContributionModel>>{};
    
    for (final contribution in contributions) {
      final dateKey = _formatDate(contribution.deletedAt.toDate());
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(contribution);
    }
    
    // Sort dates in descending order
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    final sortedMap = <String, List<DeletedContributionModel>>{};
    for (final key in sortedKeys) {
      // Sort contributions within each date by time (newest first)
      grouped[key]!.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      sortedMap[key] = grouped[key]!;
    }
    
    return sortedMap;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dddateOnly = DateTime(date.year, date.month, date.day);
    
    if (dddateOnly == today) return 'Today';
    if (dddateOnly == yesterday) return 'Yesterday';
    
    return DateFormat('dd MMM yyyy').format(date);
  }
// Add this method in the _DeletedContributionsScreenState class
String _formatTime(DateTime date) {
  return DateFormat('hh:mm a').format(date);
}


  Future<void> _restoreContribution(DeletedContributionModel record) async {
    try {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final adminName = userDoc.data()?['displayName'] ?? 'Admin';
      
      await _deletedService.restoreDeletedContribution(
        deletedRecordId: record.deletedContributionId,
        adminId: user.uid,
        adminName: adminName,
      );
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Contribution restored successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔹 Modern Search Bar
  Widget _buildModernSearchBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color searchBg = isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.surface(context).withValues(alpha: 0.8);
    final Color searchBorder = isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context);
    final Color textColor = isDark ? Colors.white : AppColors.textPrimary(context);
    final Color iconColorVal = isDark ? Colors.white70 : Colors.black;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
          letterSpacing: 0.3,
        ),
        cursorColor: isDark ? Colors.white : AppColors.primary(context),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: 'Search deleted contributions...',
          hintStyle: TextStyle(
            color: textColor.withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: iconColorVal,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: iconColorVal,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: searchBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: BorderSide(
              color: searchBorder,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: BorderSide(
              color: searchBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: BorderSide(
              color: searchBorder,
            ),
          ),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border(context),
              width: 0.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContributionDetails(DeletedContributionModel record, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: const Color(0x66000000),
          child: GestureDetector(
            onTap: () {},
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              snap: true,
              snapSizes: const [0.5, 0.7, 0.9],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0F1F1D)
                        : const Color(0xFFF8FDFC),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 32,
                        spreadRadius: 0,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border(context).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Deleted Contribution Details',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary(context),
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Deleted on: ${DateFormat('dd MMM yyyy • hh:mm a').format(record.deletedAt.toDate())}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Amount Card
                              Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  color: AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Amount
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '₹',
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade800,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          record.amount.toStringAsFixed(2),
                                          style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.red.shade800,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      record.contributorName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Deletion Details
                              _buildDetailSection(
                                context,
                                title: 'Deletion Information',
                                icon: Icons.delete_outline,
                                color: Colors.red,
                                children: [
                                  _buildDetailItem(
                                    context,
                                    label: 'Deleted By',
                                    value: record.deletedByUserName,
                                    icon: Icons.person_outline,
                                  ),
                                  _buildDetailItem(
                                    context,
                                    label: 'Reason',
                                    value: record.deletionReason.isNotEmpty 
                                        ? record.deletionReason 
                                        : 'No reason provided',
                                    icon: Icons.description_outlined,
                                  ),
                                  _buildDetailItem(
                                    context,
                                    label: 'Auto-deletes on',
                                    value: record.formattedTTLExpiry,
                                    icon: Icons.timer_outlined,
                                  ),
                                  if (record.shouldShowDeletionWarning) ...[
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber,
                                            color: Colors.orange.shade700,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Will auto-delete in ${record.daysUntilAutoDeletion} days',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              
                              // Original Contribution Details
                              _buildDetailSection(
                                context,
                                title: 'Original Contribution',
                                icon: Icons.payments_outlined,
                                color: AppColors.primary(context),
                                children: [
                                  _buildDetailItem(
                                    context,
                                    label: 'Payment Method',
                                    value: record.paymentMethod,
                                    icon: Icons.payment_outlined,
                                  ),
                                  _buildDetailItem(
                                    context,
                                    label: 'Added By',
                                    value: record.addedByUserName ?? 'Unknown',
                                    icon: Icons.person_add_alt_1_outlined,
                                  ),
                                  _buildDetailItem(
                                    context,
                                    label: 'Created Date',
                                    value: record.formattedOriginalDate,
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                  if (record.isEdited) ...[
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.edit_outlined,
                                                color: Colors.orange.shade700,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'This contribution was edited',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (record.editReason != null && record.editReason!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Edit reason: ${record.editReason}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                      
                      // Bottom Actions
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          border: Border(
                            top: BorderSide(
                              color: AppColors.border(context),
                              width: 1.5,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary(context),
                                  side: BorderSide(
                                    color: AppColors.border(context),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (record.canBeRestored) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showRestoreDialog(record, context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary(context),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 4,
                                    shadowColor: Colors.green.withValues(alpha: 0.3),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.restore, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Restore',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showRestoreDialog(DeletedContributionModel record, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.green),
            SizedBox(width: 10),
            Text('Restore Contribution?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to restore this contribution? It will be moved back to active contributions.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Member: ${record.contributorName}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ₹${record.amount.toStringAsFixed(2)}',
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deleted on: ${record.formattedDeletedDate}',
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _restoreContribution(record);
            },
            child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedContributionCard(DeletedContributionModel record, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Colors.red;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showContributionDetails(record, context),
        child: Stack(
          children: [
            // Vertical accent bar
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              width: 3.5,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.delete_sweep_outlined,
                      color: accentColor.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.contributorName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'By ${record.deletedByUserName}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.textTertiary(context).withValues(alpha: 0.3), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(record.deletedAt.toDate()),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Trailing info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${record.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.textPrimary(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (record.shouldShowDeletionWarning)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${record.daysUntilAutoDeletion}d left',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary(context).withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRefresh() {
    setState(() {});
  }

  Widget _buildSliverAppBar(BuildContext context) {
    const double toolbarHeight = 84.0;
    const double bottomContentHeight = 64.0;
    const double totalBottomHeight = bottomContentHeight + 24.0;
    const double collapsedHeight = toolbarHeight + totalBottomHeight;
    const double expandedHeight = collapsedHeight + 36.0;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      toolbarHeight: toolbarHeight,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.background(context),
      automaticallyImplyLeading: false,
      leading: showBackButton 
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.textPrimary(context)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          final double currentHeight = top;
          final double progress = ((currentHeight - collapsedHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
          final double fontSize = 18 + (2 * progress);

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
              FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                centerTitle: true,
                titlePadding: EdgeInsets.only(bottom: totalBottomHeight + 10),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Deleted Contributions',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary(context),
                        letterSpacing: -0.5 - (0.5 * progress),
                      ),
                    ),
                    if (progress > 0.5)
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(totalBottomHeight),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildModernSearchBar(),
            ),
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.radiusExtraLarge),
                  topRight: Radius.circular(AppDimensions.radiusExtraLarge),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final communityId = context.watch<AppAuthProvider>().user?.communityId ?? '';
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(context),
            ],
            body: StreamBuilder<List<DeletedContributionModel>>(
              stream: _getDeletedContributions(communityId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppColors.error(context)),
                        const SizedBox(height: 16),
                        Text('Error loading deleted contributions', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: AppColors.primary(context)));
                }
                
                final deletedContributions = snapshot.data ?? [];
                final filtered = deletedContributions.where((record) {
                  if (_searchQuery.isEmpty) return true;
                  return record.contributorName.toLowerCase().contains(_searchQuery) ||
                        record.amount.toString().contains(_searchQuery);
                }).toList();
                
                final groupedByDate = _groupContributionsByDate(filtered);
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, size: 72, color: AppColors.textTertiary(context)),
                        const SizedBox(height: 20),
                        Text(_searchQuery.isEmpty ? 'No deleted contributions' : 'No matching contributions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                      ],
                    ),
                  );
                }
                
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: () async {
                        HapticHelper.light();
                        _onRefresh();
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final dateKey = groupedByDate.keys.toList()[index];
                          final items = groupedByDate[dateKey]!;
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.card(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border(context).withValues(alpha: 0.6)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: AppColors.border(context).withValues(alpha: 0.3)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary(context).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary(context)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          dateKey.toUpperCase(), 
                                          style: TextStyle(
                                            fontSize: 12, 
                                            fontWeight: FontWeight.w800, 
                                            color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1), 
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${items.length} ARCHIVED', 
                                          style: const TextStyle(
                                            fontSize: 10, 
                                            fontWeight: FontWeight.w900, 
                                            color: Colors.red,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1, 
                                    thickness: 0.5, 
                                    color: AppColors.border(context).withValues(alpha: 0.4), 
                                    indent: 16, 
                                    endIndent: 16,
                                  ),
                                  itemBuilder: (context, itemIndex) => _buildDeletedContributionCard(items[itemIndex], context),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: groupedByDate.length,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                  ],
                );
              },
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}








