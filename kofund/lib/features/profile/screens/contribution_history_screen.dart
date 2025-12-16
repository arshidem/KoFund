import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/widgets/loading_indicator.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/history/utils/contribution_receipt_pdf.dart';
import 'package:kofund/features/history/providers/history_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:kofund/features/auth/models/user_model.dart';

class ContributionHistoryScreen extends StatefulWidget {
  const ContributionHistoryScreen({super.key});

  @override
  State<ContributionHistoryScreen> createState() => _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState extends State<ContributionHistoryScreen> {
  String? _currentUserId;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: ContributionHistoryScreen initState called');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadHistory();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🔄 DEBUG: didChangeDependencies called');
    
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    // Check if user has changed
    if (user != null && user.uid != _currentUserId) {
      print('👤 DEBUG: User changed from $_currentUserId to ${user.uid}');
      _currentUserId = user.uid;
      
      // Reset screen state for new user
      _resetScreenForNewUser();
      
      // Load contribution history for new user
      if (mounted) {
        _checkAuthAndLoadHistory();
      }
    }
    
    if (user != null && _isInitialLoad && _currentUserId == null) {
      print('👤 DEBUG: First load for user ${user.uid}');
      _currentUserId = user.uid;
      _checkAuthAndLoadHistory();
    }
  }

  void _resetScreenForNewUser() {
    if (!mounted) return;
    
    print('🔄 DEBUG: Resetting contribution screen for new user');
    
    setState(() {
      _isInitialLoad = true;
    });
    
    // Reset the provider as well
    final profileProvider = context.read<ProfileProvider>();
    profileProvider.clearAllData();
  }

  void _checkAuthAndLoadHistory() {
    if (!mounted) return;
    
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    print('🔍 DEBUG: Checking auth state for contributions - UID: ${user?.uid}');
    
    if (user == null) {
      print('❌ DEBUG: No user found for contributions');
      setState(() {
        _isInitialLoad = false;
      });
      return;
    }
    
    print('✅ DEBUG: User found, loading contribution history...');
    _loadContributionHistory();
  }

  Future<void> _loadContributionHistory() async {
    if (!mounted) return;
    
    print('🔄 DEBUG: Loading contribution history...');
    
    try {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.getUserContributionHistory();
      
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
        print('✅ DEBUG: Contribution history loaded successfully');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
        print('❌ DEBUG: Error loading contribution history: $error');
      }
    }
  }

  Future<void> _refreshData() async {
    print('🔄 DEBUG: Refreshing contribution history');
    
    try {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.getUserContributionHistory();
      print('✅ DEBUG: Refresh completed successfully');
    } catch (e) {
      print('❌ DEBUG: Refresh failed: $e');
    }
  }

  // ✅ FIXED: Create HistoryItem with proper user ID
  HistoryItem _convertToHistoryItem(Map<String, dynamic> contribution, String userId) {
    final createdAt = (contribution['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final programTitle = contribution['programTitle'] ?? 'Unknown Program';
    final amount = (contribution['amount'] ?? 0).toDouble();
    final paymentMethod = contribution['paymentMethod'] ?? 'Unknown';
    final contributionId = contribution['contributionId'] ?? 'unknown_id';
    final programId = contribution['programId'] ?? '';

    return HistoryItem(
      id: 'contrib_$contributionId',
      type: HistoryItemType.contribution,
      title: programTitle,
      subtitle: 'Paid via ${_formatPaymentMethod(paymentMethod)}',
      amount: amount,
      date: createdAt,
      userId: userId,
      programId: programId,
      category: 'Contribution',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final authProvider = context.watch<AppAuthProvider>();
    final contributionHistory = profileProvider.contributionHistory;
    final currentUser = authProvider.user;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('My Contributions'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        actions: [
          if (currentUser != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _buildContent(profileProvider, authProvider, currentUser),
      ),
    );
  }

  Widget _buildContent(ProfileProvider profileProvider, AppAuthProvider authProvider, UserModel? currentUser) {
    // Show loading on initial load
    if (_isInitialLoad) {
      return const LoadingIndicator();
    }

    // Check if user is not logged in
    if (currentUser == null) {
      return _buildAuthRequiredState();
    }

    // Show provider loading state
    if (profileProvider.isLoading) {
      return const LoadingIndicator();
    }

    // Show provider error state
    if (profileProvider.error != null) {
      return _buildErrorState(profileProvider.error!);
    }

    final contributionHistory = profileProvider.contributionHistory;

    // Check if no contributions
    if (contributionHistory.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildStatsCards(contributionHistory),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: contributionHistory.length,
            itemBuilder: (context, index) {
              final contribution = contributionHistory[index];
              return _buildContributionListItem(contribution, authProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthRequiredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Sign In Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Please sign in to view your contribution history',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to sign in screen
              // Navigator.pushNamed(context, '/signin');
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Unable to Load Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(List<Map<String, dynamic>> contributions) {
    final totalAmount = contributions.fold(0.0, (sum, c) => sum + (c['amount'] as double));
    final totalCount = contributions.length;
    final averageAmount = totalCount > 0 ? totalAmount / totalCount : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Total Paid',
              value: '₹${totalAmount.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Contributions',
              value: totalCount.toString(),
              icon: Icons.payments,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContributionListItem(Map<String, dynamic> contribution, AppAuthProvider authProvider) {
    final programTitle = contribution['programTitle'] ?? 'Unknown Program';
    final amount = (contribution['amount'] ?? 0).toDouble();
    final paymentMethod = contribution['paymentMethod'] ?? 'Unknown';
    final createdAt = (contribution['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final programType = contribution['programType'] ?? ProgramTypes.general;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card(context).withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  _showContributionDetails(contribution, authProvider);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.payments,
                          size: 24,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              programTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatRelativeDate(createdAt),
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
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPaymentMethodColor(paymentMethod).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getPaymentMethodColor(paymentMethod).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _formatPaymentMethod(paymentMethod),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getPaymentMethodColor(paymentMethod),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ UPDATE: Show contribution details method
  void _showContributionDetails(Map<String, dynamic> contribution, AppAuthProvider authProvider) {
    final programTitle = contribution['programTitle'] ?? 'Unknown Program';
    final amount = (contribution['amount'] ?? 0).toDouble();
    final paymentMethod = contribution['paymentMethod'] ?? 'Unknown';
    final createdAt = (contribution['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final communityLabel = authProvider.user?.communityId ?? '';

    // ✅ FIXED: Create HistoryItem with proper user ID
    final historyItem = _convertToHistoryItem(contribution, authProvider.user?.uid ?? '');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Text(
                programTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Details
              _buildDetailRow('Amount:', '₹${amount.toStringAsFixed(2)}', context),
              _buildDetailRow('Payment Method:', _formatPaymentMethod(paymentMethod), context),
              _buildDetailRow('Date:', _formatFullDate(createdAt), context),
              _buildDetailRow('Status:', 'Completed', context),
              const SizedBox(height: 20),
              
              // Receipt Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt),
                  onPressed: () {
                    Navigator.pop(context); // Close details sheet
                    _generateReceipt(historyItem, communityLabel);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text("Download Receipt"),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary(context),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Generate receipt method
  void _generateReceipt(HistoryItem item, String communityLabel) {
    ContributionReceiptPdf.showPreview(
      context,
      item,
      communityName: communityLabel,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payments,
              size: 80,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No Contributions Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t made any contributions yet. Start contributing to programs to see them here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for relative dates
  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method for full date formatting
  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Helper method for payment method formatting
  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'online': return 'Online';
      case 'upi': return 'UPI';
      case 'bank_transfer': return 'Bank Transfer';
      default: return method;
    }
  }

  // Helper method for payment method colors
  Color _getPaymentMethodColor(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Colors.orange;
      case 'online':
        return Colors.blue;
      case 'upi':
        return Colors.purple;
      case 'bank_transfer':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}