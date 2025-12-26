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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "Recent Transactions" and "See all"
        _buildHeaderSection(context, user),
        const SizedBox(height: 8),
        
        // History list with proper user context
        _buildHistoryContent(user),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, UserModel? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Recent Transactions",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        TextButton(
          onPressed: user != null ? () => _navigateToHistoryScreen(context) : null,
          style: TextButton.styleFrom(
            foregroundColor: user != null ? AppColors.primary(context) : AppColors.textSecondary(context),
          ),
          child: const Text("See all"),
        ),
      ],
    );
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
      return _buildNoUserState(context);
    }
    
    // If user has no community
    if (user.communityId == null || user.communityId!.isEmpty) {
      return _buildNoCommunityState(context);
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
          return _buildNoHistoryState(context);
        }

        // Show first 3-4 history items
        final displayItems = items.take(4).toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ...displayItems.map((item) => _buildHistoryItem(
                item: item,
                context: context,
              )),
              // Add spacing after last item
              if (displayItems.isNotEmpty) const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoUserState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_outline,
            size: 48,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            "Sign in to View History",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please sign in to see your transaction history",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCommunityState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_outlined,
            size: 48,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            "No Community",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Join a community to see transaction history",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildHistoryItem({
  required HistoryItem item,
  required BuildContext context,
}) {
  final bool isContribution = item.type == HistoryItemType.contribution;
  final iconColor = isContribution ? AppColors.revenue(context) : AppColors.expense(context);
  final amountText = (isContribution ? '+ ' : '- ') + _formatAmount(item.amount);

  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Add onTap functionality if needed
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                // Circular icon with wallet + arrow
Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: iconColor.withOpacity(0.1),
  ),
  child: isContribution
      ? Stack(
          children: [
            // Wallet icon (centered)
            Center(
              child: Icon(
                Icons.account_balance_wallet,
                color: iconColor,
                size: 20,
              ),
            ),
            // Arrow DOWN at top center for contribution (money coming in from above)
            Positioned(
              top: 4,  // Position at top center
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_downward, // Arrow DOWN for contribution
                  color: iconColor,
                  size: 10,
                ),
              ),
            ),
          ],
        )
      : Stack(
          children: [
            // Wallet icon (centered)
            Center(
              child: Icon(
                Icons.account_balance_wallet,
                color: iconColor,
                size: 20,
              ),
            ),
            // Arrow UP at top center for expense (money going out to above)
            Positioned(
              top: 4,  // Position at top center
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_upward, // Arrow UP for expense
                  color: iconColor,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
),
                const SizedBox(width: 12),
                
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Time and amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(item.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      
      // Horizontal divider
      Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border(context),
        indent: 16,
        endIndent: 16,
      ),
    ],
  );
}

 Widget _buildLoadingState(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        // Show 3 skeleton items for loading
        for (int i = 0; i < 3; i++) ...[
          _buildHistoryItemSkeleton(context),
          if (i < 2) // Add divider between items (except last one)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border(context).withOpacity(0.3),
              indent: 16,
              endIndent: 16,
            ),
        ],
      ],
    ),
  );
}

Widget _buildHistoryItemSkeleton(BuildContext context) {
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          // Skeleton circular icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.textTertiary(context).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          
          // Skeleton text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                Container(
                  width: double.infinity,
                  height: 16,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                
                // Subtitle skeleton
                Container(
                  width: double.infinity,
                  height: 14,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          
          // Skeleton time and amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Time skeleton
              Container(
                width: 60,
                height: 12,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              
              // Amount skeleton
              Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: AppColors.error(context),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Failed to load transactions',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.error(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _retryLoading,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHistoryState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_outlined,
            size: 48,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            "No Transactions Found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Transactions will appear here once contributions or expenses are added",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      final difference = now.difference(date);
      if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }
}