// lib/features/dashboard/widgets/history_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/history/providers/history_provider.dart';
import 'package:kofund/features/history/screens/history_screen.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';

class HistoryWidget extends StatefulWidget {
  const HistoryWidget({
    super.key,
  });

  @override
  State<HistoryWidget> createState() => _HistoryWidgetState();
}

class _HistoryWidgetState extends State<HistoryWidget> {
  String? _currentUserId;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: HistoryWidget initState called');
    
    // Initial load after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Listen for auth changes
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    // Check if user has changed
    if (user?.uid != _currentUserId) {
      print('👤 DEBUG: User changed in HistoryWidget - from $_currentUserId to ${user?.uid}');
      _currentUserId = user?.uid;
      
      // Reset state for new user
      _resetForNewUser();
    }
  }

  void _resetForNewUser() {
    print('🔄 DEBUG: Resetting HistoryWidget for new user');
    
    // Reset the HistoryProvider data
    final historyProvider = context.read<HistoryProvider>();
    historyProvider.clearDataForUserChange();
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }
    
    // Load data for new user
    _checkAuthAndLoadData();
  }

  void _checkAuthAndLoadData() {
    if (!mounted) return;
    
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    final historyProvider = context.read<HistoryProvider>();
    
    if (user == null) {
      print('❌ DEBUG: No user found in HistoryWidget');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Please sign in to view history';
        });
      }
      
      // Clear provider data when no user
      historyProvider.clearDataForUserChange();
      return;
    }
    
    // Check if user has community
    if (user.communityId == null || user.communityId!.isEmpty) {
      print('❌ DEBUG: User has no community');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'You are not part of any community';
        });
      }
      return;
    }
    
    print('✅ DEBUG: User found with community ${user.communityId}, loading history...');
    _loadHistoryData(user.communityId!);
  }

  void _loadHistoryData(String communityId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      final historyProvider = context.read<HistoryProvider>();
      
      // Set the community ID for the provider
      historyProvider.setUserCommunity(communityId);
      
      // Wait a moment for the provider to start loading
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('❌ DEBUG: Error loading history data: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load transactions: $error';
        });
      }
    }
  }

  void _retryLoading() {
    _checkAuthAndLoadData();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final user = authProvider.user;
    
    return _buildHistoryContent(user);
  }

  void _navigateToHistoryScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HistoryScreen(),
      ),
    );
  }

  Widget _buildHistoryContent(UserModel? user) {
    // If no user is logged in
    if (user == null) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: 'Sign in to View History',
        message: 'Please sign in to see your transaction history',
      );
    }
    
    // If user has no community
    if (user.communityId == null || user.communityId!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_outlined,
        title: 'No Community',
        message: 'Join a community to see transaction history',
      );
    }
    
    // If loading
    if (_isLoading) {
      return _buildLoadingState(context);
    }
    
    // If error
    if (_hasError) {
      return _buildErrorState(context);
    }
    
    // Show history from provider
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        // Check if provider has the correct community
        if (historyProvider.communityId != user.communityId) {
          print('⚠️ DEBUG: Provider community (${historyProvider.communityId}) doesn\'t match user community (${user.communityId})');
          return _buildLoadingState(context);
        }
        
        final items = historyProvider.items;
        
        // If no transactions
        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_outlined,
            title: 'No Transactions Found',
            message: 'Transactions will appear here once contributions or expenses are added',
          );
        }

        // Show first 3-4 history items
        final displayItems = items.take(4).toList();

        return _buildRecentTransactionsList(displayItems, context, user);
      },
    );
  }

  Widget _buildRecentTransactionsList(List<HistoryItem> items, BuildContext context, UserModel? user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header (compact - matching programs widget style)
          Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: Row(
    children: [
      Icon(
        Icons.history_rounded,
        size: 18,
        color: AppColors.primary(context),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      if (items.length >= 3 && user != null)
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToHistoryScreen(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'See all',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary(context),
              ),
            ),
          ),
        ),
    ],
  ),
),
SizedBox(height: 4),

            /// Transaction list
        MediaQuery.removePadding(
  context: context,
  removeTop: true,
  child: ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    separatorBuilder: (_, __) => Divider(
      height: 2,
      thickness: 0.8,
      color: AppColors.border(context),
    ),
    itemBuilder: (context, index) {
      return _buildTransactionListItem(items[index]);
    },
  ),
),

          ],
        ),
      ),
    );
  }

  Widget _buildTransactionListItem(HistoryItem item) {
    final bool isContribution = item.type == HistoryItemType.contribution;
    final iconColor = isContribution ? AppColors.revenue(context) : AppColors.expense(context);
    final amountText = (isContribution ? '+ ' : '- ') + _formatAmount(item.amount);
    final statusText = isContribution ? 'Received' : 'Paid';
    final statusColor = isContribution ? Colors.green : Colors.orange;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
       onTap: () {
  final messenger = ScaffoldMessenger.of(context);

  // Clear previous snackbars
  messenger.clearSnackBars();

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
      content: const Text(
        'To see more details about this transaction, go to the History tab',
        style: TextStyle(fontSize: 13),
      ),
      action: SnackBarAction(
        label: 'Go',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HistoryScreen(),
            ),
          );
        },
      ),
    ),
  );
},

        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              /// Icon container (square, matching programs widget)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 10),

              /// Title + date (compact layout)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              /// Right side: Amount and status badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  /// Amount (compact)
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  /// Status badge (compact - matching programs widget)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header skeleton
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 120,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            /// Skeleton items
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildTransactionSkeletonItem(context),
              if (i < 2) 
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSkeletonItem(BuildContext context) {
    return Row(
      children: [
        /// Icon skeleton
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.textTertiary(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        
        /// Text content skeleton
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        
        /// Amount and status skeleton
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 60,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 50,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.error(context),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Failed to load transactions',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error(context),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _retryLoading,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary(context).withOpacity(0.3)),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $amPm';
  }
}