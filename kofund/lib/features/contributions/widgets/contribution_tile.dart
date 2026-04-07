import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/contribution_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/contribution_provider.dart';
import '../../../core/services/user_service.dart';
import '../../programs/utils/contribution_receipt_pdf.dart';
import '../screens/edit_contribution_screen.dart';

class ContributionTile extends StatelessWidget {
  final ContributionModel contribution;
  final bool showMenu;

  const ContributionTile({
    super.key,
    required this.contribution,
    this.showMenu = true,
  });

  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    if (currentUser == null) return false;
    return currentUser.role == 'admin' || currentUser.isAdmin == true;
  }

  bool _isContributor(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    return currentUser?.uid == contribution.userId;
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin(context);
    final isContributor = _isContributor(context);
    final canShowMenu = showMenu && (isAdmin || isContributor);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showContributionDetails(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.payments,
                      color: AppColors.success(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              contribution.contributorName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (contribution.isEdited)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Edited',
                                    style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatPaymentMethod(contribution.paymentMethod)} • ${DateFormat('dd/MM/yyyy').format(contribution.createdAt.toDate())}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '₹${contribution.amount.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary(context)),
                      ),
                      if (canShowMenu)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: AppColors.textSecondary(context), size: 20),
                            padding: EdgeInsets.zero,
                            onSelected: (value) => _handleMenuAction(value, context),
                            itemBuilder: (context) => _buildMenuItems(context, isAdmin, isContributor),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.border(context)),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context, bool isAdmin, bool isContributor) {
    List<PopupMenuEntry<String>> items = [
      const PopupMenuItem(
        value: 'view_details',
        child: Row(children: [Icon(Icons.info_outline, size: 18), SizedBox(width: 8), Text('View Details')]),
      ),
    ];

    if (isAdmin) {
      items.add(const PopupMenuItem(
        value: 'edit',
        child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
      ));
    }

    if (isContributor || isAdmin) {
      items.add(const PopupMenuItem(
        value: 'receipt',
        child: Row(children: [Icon(Icons.receipt, size: 18), SizedBox(width: 8), Text('Get Receipt')]),
      ));
    }

    if (isAdmin) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: 'delete',
        child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
      ));
    }

    return items;
  }

  void _handleMenuAction(String value, BuildContext context) {
    switch (value) {
      case 'view_details':
        _showContributionDetails(context);
        break;
      case 'edit':
        _editContribution(context);
        break;
      case 'receipt':
        _generateReceipt(context);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showContributionDetails(BuildContext context) {
    // Reusing the implementation logic (simplified for brevity or fully copied)
    // For now, I'll use a placeholder or copy the key parts.
    // Actually, I'll copy the full details view since it's premium.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContributionDetailsSheet(contribution: contribution),
    );
  }

  void _editContribution(BuildContext context) {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditContributionScreen(
          contributionId: contribution.contributionId,
          onSave: (updated) {
            if (updated != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Updated successfully'), backgroundColor: AppColors.success(context)),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _generateReceipt(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final userService = UserService();
      final user = await userService.getUserById(contribution.userId);
      final contributorName = user?.displayName ?? user?.email ?? 'User';
      
      if (context.mounted) Navigator.pop(context);
      
      await ContributionReceiptPdf.generateAndShowReceipt(
        context: context,
        contribution: contribution,
        contributorName: contributorName,
        programName: contribution.programName,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: Text('Are you sure you want to delete this contribution of ₹${contribution.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContribution(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteContribution(BuildContext context) async {
    final reason = await _showDeleteReasonDialog(context);
    if (reason == null) return;

    try {
      final provider = Provider.of<ContributionProvider>(context, listen: false);
      await provider.deleteContribution(contribution.contributionId, reason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Deleted successfully'), backgroundColor: AppColors.success(context)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<String?> _showDeleteReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Deletion'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter reason...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Delete')),
        ],
      ),
    );
  }
}

class _ContributionDetailsSheet extends StatelessWidget {
  final ContributionModel contribution;
  const _ContributionDetailsSheet({required this.contribution});

  @override
  Widget build(BuildContext context) {
    // Premium details sheet implementation (simplified version of the one in program_contributions_tab)
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Contribution Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                const SizedBox(height: 20),
                _buildAmountCard(context),
                const SizedBox(height: 20),
                _buildInfoRow(context, Icons.payment, 'Payment Method', contribution.paymentMethod),
                _buildInfoRow(context, Icons.event, 'Date', DateFormat('dd MMM yyyy').format(contribution.createdAt.toDate())),
                if (contribution.isMonthlyContribution)
                  _buildInfoRow(context, Icons.calendar_month, 'Month', contribution.monthDisplayName),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Text('Amount Paid', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 8),
          Text('₹${contribution.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
          const SizedBox(height: 8),
          Text(contribution.contributorName, style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary(context)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
            ],
          ),
        ],
      ),
    );
  }
}
