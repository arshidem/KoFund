// lib/features/history/widgets/add_action_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/app_auth_provider.dart';
import 'add_contribution_modal.dart';
import 'add_expense_modal.dart';

class AddActionSheet extends StatelessWidget {
  const AddActionSheet({Key? key}) : super(key: key);

  void _showContributionModal(BuildContext context) {
    Navigator.pop(context); // Close action sheet
    // Show contribution modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddContributionModal(),
    );
  }

  void _showExpenseModal(BuildContext context) {
    Navigator.pop(context); // Close action sheet
    // Show expense modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddExpenseModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final isAdmin = auth.user?.isAdmin == true;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title and X icon on same line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between title and X
            children: [
              // Empty container to balance the space (pushes title to center)
              const SizedBox(width: 40), // Same width as the X button for balance
              
              // Title
              Text(
                'Add New',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              
              // X button
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.grey[600],
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (isAdmin) ...[
            // Admin sees both options
            _buildOptionItem(
              context,
              icon: Icons.payments,
              title: 'Add Contribution',
              subtitle: 'Record a member contribution',
              onTap: () => _showContributionModal(context),
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildOptionItem(
              context,
              icon: Icons.receipt,
              title: 'Add Expense',
              subtitle: 'Record program expense',
              onTap: () => _showExpenseModal(context),
              color: Colors.orange,
            ),
          ] else ...[
            // Normal user sees only expense
            _buildOptionItem(
              context,
              icon: Icons.receipt,
              title: 'Add Expense',
              subtitle: 'Record program expense (requires approval)',
              onTap: () => _showExpenseModal(context),
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}