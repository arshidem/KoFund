import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';
import 'package:kofund/features/events/utils/contribution_receipt_image.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/skeleton/contribution_history_skeleton.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/ads/simple_banner_ad.dart';
import 'package:kofund/core/utils/haptic_helper.dart';

// Move ChangeEntry to top level
class ChangeEntry {
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  
  ChangeEntry({required this.fieldName, this.oldValue, this.newValue});
}

class ContributionHistoryScreen extends StatefulWidget {
  const ContributionHistoryScreen({super.key});

  @override
  State<ContributionHistoryScreen> createState() => _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState extends State<ContributionHistoryScreen> {
  String? _currentUserId;
  bool _isInitialLoad = true;
  final bool _isRefreshing = false;
  // REMOVED: final RefreshController _refreshController = RefreshController();
  
  @override
  void initState() {
    super.initState();
    debugPrint('🔄 DEBUG: ContributionHistoryScreen initState called');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadHistory();
    });
  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🔄 DEBUG: didChangeDependencies called');
    
    final _authProvider = context.read<AppAuthProvider>();
    final user = _authProvider.user;
    
    // Check if user has changed
    if (user != null && user.uid != _currentUserId) {
      debugPrint('👤 DEBUG: User changed from $_currentUserId to ${user.uid}');
      _currentUserId = user.uid;
      
      // Reset screen state for new user
      _resetScreenForNewUser();
      
      // Load contribution history for new user
      if (mounted) {
        _checkAuthAndLoadHistory();
      }
    }
    
    if (user != null && _isInitialLoad && _currentUserId == null) {
      debugPrint('👤 DEBUG: First load for user ${user.uid}');
      _currentUserId = user.uid;
      _checkAuthAndLoadHistory();
    }
  }

  void _resetScreenForNewUser() {
    if (!mounted) return;
    
    debugPrint('🔄 DEBUG: Resetting contribution screen for new user');
    
    setState(() {
      _isInitialLoad = true;
    });
    
    // Reset the provider as well
    final profileProvider = context.read<ProfileProvider>();
    profileProvider.clearAllData();
  }
void _debugFirestoreContribution(String contributionId) async {
  try {
    debugPrint('🔍 DEBUG: Fetching contribution $contributionId directly from Firestore');
    
    final doc = await FirebaseFirestore.instance
        .collection('contributions')
        .doc(contributionId)
        .get();
    
    if (doc.exists) {
      final data = doc.data();
      debugPrint('✅ Contribution exists in Firestore');
      debugPrint('📋 All fields:');
      data?.forEach((key, value) {
        debugPrint('  - $key: $value (type: ${value.runtimeType})');
      });
      
      // Check specifically for edit-related fields
      debugPrint('🔎 Edit-related fields check:');
      final editFields = ['isEdited', 'editHistory', 'lastEditedAt', 'lastEditedByUserId', 'editReason'];
      for (var field in editFields) {
        if (data?.containsKey(field) ?? false) {
          debugPrint('  ✅ $field exists: ${data![field]}');
        } else {
          debugPrint('  ❌ $field does NOT exist');
        }
      }
    } else {
      debugPrint('❌ Contribution does not exist in Firestore');
    }
  } catch (e) {
    debugPrint('❌ Error fetching from Firestore: $e');
  }
}
  void _checkAuthAndLoadHistory() {
    if (!mounted) return;
    
    final _authProvider = context.read<AppAuthProvider>();
    final user = _authProvider.user;
    
    debugPrint('🔍 DEBUG: Checking auth state for contributions - UID: ${user?.uid}');
    
    if (user == null) {
      debugPrint('❌ DEBUG: No user found for contributions');
      setState(() {
        _isInitialLoad = false;
      });
      return;
    }
    
    debugPrint('✅ DEBUG: User found, loading contribution history...');
    _loadContributionHistory();
  }

  Future<void> _loadContributionHistory() async {
    if (!mounted) return;
    
    debugPrint('🔄 DEBUG: Loading contribution history...');
    
    try {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.getUserContributionHistory();
      
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
        debugPrint('✅ DEBUG: Contribution history loaded successfully');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
        debugPrint('❌ DEBUG: Error loading contribution history: $error');
      }
    }
  }

  Future<void> _refreshData() async {
    HapticHelper.light();
    debugPrint('🔄 DEBUG: Refreshing contribution history');
    
    try {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.getUserContributionHistory();
      debugPrint('✅ DEBUG: Refresh completed successfully');
    } catch (e) {
      debugPrint('❌ DEBUG: Refresh failed: $e');
    }
  }

  


  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final _authProvider = context.watch<AppAuthProvider>();
    final contributionHistory = profileProvider.contributionHistory;
    final currentUser = _authProvider.user;

    return GradientSheetScaffold(
      title: 'My Contributions',
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _refreshData,
                ),
                SliverToBoxAdapter(
                  child: _buildContent(profileProvider, _authProvider, currentUser),
                ),
              ],
            ),
          ),
          // Fixed bottom banner ad
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[900] 
                : Colors.grey[100],
            child: const SimpleBannerAd(),
          ),
        ],
      ),
    );
  }

Widget _buildContent(ProfileProvider profileProvider, AppAuthProvider _authProvider, UserModel? currentUser) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark; // Add this

  // Show loading on initial load
  if (_isInitialLoad) {
    return ContributionHistorySkeleton(
      isDarkMode: Theme.of(context).brightness == Brightness.dark
    );
  }

  // Check if user is not logged in
  if (currentUser == null) {
    return _buildAuthRequiredState();
  }

  // Show provider loading state
  if (profileProvider.isLoading) {
    return ContributionHistorySkeleton(
      isDarkMode: isDarkMode,
    );
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

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsCards(contributionHistory),
        const SizedBox(height: 32),
          _buildListHeader('Contribution History'),
        _buildSettingsGroup(
          children: List.generate(contributionHistory.length, (index) {
            final contribution = contributionHistory[index];
            return Column(
              children: [
                _buildContributionListItem(contribution, _authProvider),
                if (index < contributionHistory.length - 1) _buildItemDivider(),
              ],
            );
          }),
        ),
        const SizedBox(height: 100),
      ],
    ),
  );
}

  Widget _buildListHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context).withValues(alpha: 0.4),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primary(context),
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
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildItemDivider() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      endIndent: 20,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
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
    final totalAmount = contributions.fold(
        0.0, (sum, c) => sum + (c['amount']?.toDouble() ?? 0.0));
    final totalCount = contributions.length;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2F2F).withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            label: 'TOTAL PAID',
            value: '₹${totalAmount.toInt()}',
            icon: Icons.account_balance_wallet_rounded,
          ),
          Container(
            height: 60,
            width: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
          ),
          _buildStatItem(
            label: 'RECORDS',
            value: totalCount.toString(),
            icon: Icons.receipt_long_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color(0xFF00D2B4)),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context).withValues(alpha: 0.4),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildContributionListItem(
      Map<String, dynamic> contribution, AppAuthProvider _authProvider) {
    final EventTitle = contribution['EventTitle'] ?? 'Unknown event';
    final amount = (contribution['amount'] ?? 0).toDouble();
    final paymentMethod = contribution['paymentMethod'] ?? 'Unknown';
    final createdAt =
        (contribution['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final isEdited = _getIsEditedStatus(contribution);
    final monthDisplayName = contribution['monthDisplayName'] ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showContributionDetails(contribution, _authProvider);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEdited
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppColors.primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: isEdited ? Colors.orange : AppColors.primary(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            EventTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isEdited) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'EDITED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthDisplayName.isNotEmpty
                          ? '$monthDisplayName • ${_formatPaymentMethod(paymentMethod)}'
                          : _formatPaymentMethod(paymentMethod),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary(context)
                            .withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${amount.toInt()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color:
                          isEdited ? Colors.orange : AppColors.primary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          AppColors.textPrimary(context).withValues(alpha: 0.3),
                      fontWeight: FontWeight.w600,
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

// Add this helper method to properly handle isEdited status
bool _getIsEditedStatus(Map<String, dynamic> contribution) {
  final isEdited = contribution['isEdited'];
  
  // Handle different data Types
  if (isEdited is bool) {
    return isEdited;
  } else if (isEdited is String) {
    return isEdited.toLowerCase() == 'true';
  } else if (isEdited is int) {
    return isEdited == 1;
  }
  
  // Also check if there's edit history
  final editHistory = contribution['editHistory'];
  if (editHistory is List && editHistory.isNotEmpty) {
    return true;
  }
  
  return false;
}

// Helper method to format time
String _formatTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $amPm';
}
// Add debug method
void _debugContributionData(Map<String, dynamic> contribution) {
  debugPrint('🔍 DEBUG Contribution Data:');
  debugPrint('  - isEdited: ${contribution['isEdited']} (type: ${contribution['isEdited']?.runtimeType})');
  debugPrint('  - has editHistory: ${contribution['editHistory'] != null}');
  debugPrint('  - editHistory type: ${contribution['editHistory']?.runtimeType}');
  debugPrint('  - editHistory length: ${(contribution['editHistory'] as List?)?.length ?? 0}');
  debugPrint('  - All keys: ${contribution.keys.toList()}');
}
// Show contribution details method with premium design - FIXED VERSION
void _showContributionDetails(Map<String, dynamic> contribution, AppAuthProvider _authProvider) {
  final EventTitle = contribution['EventTitle'] ?? 'Unknown event';
  final amount = (contribution['amount'] ?? 0).toDouble();
  final paymentMethod = contribution['paymentMethod'] ?? 'Unknown';
  final createdAt = (contribution['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
  
  // FIX: Use the helper method to check isEdited status
  final isEdited = _getIsEditedStatus(contribution);
  
  // FIX: Get monthDisplayName from the map or compute it
  final monthId = contribution['monthId'];
  final monthDisplayName = _getMonthDisplayName(monthId);
  
  final addedByUserName = contribution['addedByUserName'] ?? '';
  
  // Get formatted edit history
  final formattedEditHistory = _getFormattedEditHistory(contribution);
  
  // Get changes description from edit history
  final changesDescription = _getChangesDescription(formattedEditHistory);

  debugPrint('🔍 DEBUG _showContributionDetails:');
  debugPrint('  isEdited: $isEdited');
  debugPrint('  formattedEditHistory length: ${formattedEditHistory.length}');
  debugPrint('  changesDescription: $changesDescription');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Color(0x66000000), // Semi-transparent black overlay
        child: GestureDetector(
          onTap: () {}, // PrEvent closing when tapping inside
          child: DraggableScrollableSheet(
            initialChildSize: isEdited ? 0.8 : 0.6,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.5, 0.75, 0.95],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF0F1F1D)
                      : Color(0xFFF8FDFC),
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
                                  'Contribution Details',
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
                                    color: AppColors.primary(context).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    DateFormat('EEEE, MMMM dd • hh:mm a').format(createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isEdited)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.withValues(alpha: 0.15),
                                    Colors.orange.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 16, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edited',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
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
                            // Amount Card - Premium Design
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.border(context),
                                  width: 0.6,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ───── AMOUNT ─────
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
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        amount.toStringAsFixed(2),
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary(context),
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // ───── event NAME ─────
                                  Text(
                                    EventTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // ───── MONTH CHIP ─────
                                  if (monthDisplayName.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface(context),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.border(context),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        monthDisplayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            // ───── BASIC INFORMATION ─────
                            _buildSectionHeader(
                              context,
                              title: 'Basic Information',
                              icon: Icons.info_outline_rounded,
                            ),

                            const SizedBox(height: 10),

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
                                children: [
                                  // ───── PAYMENT METHOD ─────
                                  _buildInfoRowMinimal(
                                    context,
                                    icon: Icons.payment_rounded,
                                    label: 'Payment Method',
                                    value: _formatPaymentMethod(paymentMethod),
                                  ),

                                  if (addedByUserName.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Divider(
                                      height: 1,
                                      thickness: 0.6,
                                      color: AppColors.border(context),
                                    ),
                                    const SizedBox(height: 12),

                                    // ───── ADDED BY ─────
                                    _buildInfoRowMinimal(
                                      context,
                                      icon: Icons.person_rounded,
                                      label: 'Added By',
                                      value: addedByUserName,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            // ───── EDIT HISTORY SECTION ─────
                            if (isEdited && formattedEditHistory.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 24),

                                  Divider(
                                    thickness: 0.6,
                                    color: AppColors.border(context),
                                  ),

                                  const SizedBox(height: 20),

                                  // ───── HEADER ─────
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.history_rounded,
                                          size: 18,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Edit History',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Most recent changes first',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textTertiary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // ───── OPTIONAL SUMMARY ─────
                                  // if (changesDescription.isNotEmpty) ...[
                                  //   const SizedBox(height: 20),
                                  //   Container(
                                  //     padding: const EdgeInsets.all(16),
                                  //     decoration: BoxDecoration(
                                  //       color: AppColors.surface(context),
                                  //       borderRadius: BorderRadius.circular(16),
                                  //       border: Border.all(
                                  //         color: AppColors.border(context),
                                  //         width: 0.6,
                                  //       ),
                                  //     ),
                                  //     child: Text(
                                  //       changesDescription,
                                  //       style: TextStyle(
                                  //         fontSize: 13,
                                  //         height: 1.55,
                                  //         color: AppColors.textPrimary(context),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ],

                                  // ───── MINIMAL TIMELINE ─────
                                  if (formattedEditHistory.isNotEmpty) ...[
                                    const SizedBox(height: 24),

                                    for (final edit in formattedEditHistory)
                                      _buildEditHistoryItem(context, edit),
                                  ],
                                ],
                              ),
                            
                            // Bottom Padding
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom Action Buttons - Premium Design
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
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close details sheet
                                  _generateReceiptFromContribution(contribution, _authProvider);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary(context),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shadowColor: AppColors.primary(context).withValues(alpha: 0.3),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Get Receipt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

// Add this helper method to get month display name
String _getMonthDisplayName(String? monthId) {
  if (monthId == null || monthId.isEmpty) return '';
  
  try {
    final parts = monthId.split('-');
    if (parts.length == 2) {
      final year = parts[0];
      final month = int.parse(parts[1]);
      final date = DateTime(int.parse(year), month, 1);
      final monthName = DateFormat('MMM').format(date);
      return '$monthName $year';
    }
  } catch (e) {
    debugPrint('Error parsing monthId $monthId: $e');
    return monthId;
  }
  return monthId;
}

// Add this helper method to get changes description from edit history
String _getChangesDescription(List<Map<String, dynamic>> editHistory) {
  if (editHistory.isEmpty) return '';
  
  // Get the latest edit record
  final latestEdit = editHistory.isNotEmpty ? editHistory.first : null;
  if (latestEdit == null) return '';
  
  final changes = latestEdit['changes'] as Map<String, dynamic>?;
  if (changes == null || changes.isEmpty) return '';
  
  final List<String> changeDescriptions = [];
  
  changes.forEach((field, changeData) {
    final oldValue = changeData is Map ? changeData['old']?.toString() : null;
    final newValue = changeData is Map ? changeData['new']?.toString() : changeData?.toString();
    final fieldName = _getFieldDisplayName(field);
    
    if (oldValue != null && newValue != null) {
      changeDescriptions.add('$fieldName: $oldValue → $newValue');
    } else if (newValue != null) {
      changeDescriptions.add('$fieldName changed to $newValue');
    }
  });
  
  return changeDescriptions.join(', ');
}


// Build edit history item widget
Widget _buildEditHistoryItem(BuildContext context, Map<String, dynamic> edit) {
  final editedAt = edit['editedAt'] != null 
      ? (edit['editedAt'] as Timestamp).toDate()
      : null;
  final editedBy = edit['editedByUserName'] ?? 
                 edit['editedByUserId'] ?? 
                 'Unknown';
  final changes = edit['changes'] ?? {};
  final reason = edit['reason'];

  // Get change entries
  final changeEntries = _getChangeEntries(changes);

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
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
      children: [
        // ───── DATE + USER ─────
        Row(
          children: [
            Text(
              editedAt != null
                  ? DateFormat('MMM dd, yyyy hh:mm a').format(editedAt)
                  : 'Unknown time',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary(context),
              ),
            ),
            const Spacer(),
            Text(
              'By: $editedBy',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ───── CHANGE LINES ─────
        if (changeEntries.isNotEmpty)
          for (final change in changeEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary(context),
                  ),
                  children: [
                    const TextSpan(text: '•  '),
                    TextSpan(
                      text: '${change.fieldName}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (change.oldValue != null)
                      TextSpan(
                        text: change.oldValue,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (change.oldValue != null && change.newValue != null)
                      const TextSpan(text: '  →  '),
                    if (change.newValue != null)
                      const TextSpan(text: ''),
                    if (change.newValue != null)
                      TextSpan(
                        text: change.newValue,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),

        // ───── REASON ─────
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary(context),
            ),
          ),
        ],
      ],
    ),
  );
}

// Helper method to build minimal info rows
Widget _buildInfoRowMinimal(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(
        icon,
        size: 16,
        color: AppColors.textTertiary(context),
      ),
      const SizedBox(width: 10),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
  );
}


// Helper method to get formatted edit history
List<Map<String, dynamic>> _getFormattedEditHistory(Map<String, dynamic> contribution) {
  final editHistory = contribution['editHistory'] ?? [];
  if (editHistory is List) {
    return editHistory.whereType<Map<String, dynamic>>().toList();
  }
  return [];
}

// Helper method to get change entries
List<ChangeEntry> _getChangeEntries(Map<String, dynamic> changes) {
  final entries = <ChangeEntry>[];
  
  changes.forEach((key, value) {
    final fieldName = _getFieldDisplayName(key);
    
    String? oldValue;
    String? newValue;
    
    if (value is Map<String, dynamic>) {
      oldValue = value['old']?.toString();
      newValue = value['new']?.toString();
    } else if (value is String) {
      newValue = value;
    }
    
    entries.add(ChangeEntry(
      fieldName: fieldName, 
      oldValue: oldValue, 
      newValue: newValue
    ));
  });
  
  return entries;
}

// Helper method for field display nnames
String _getFieldDisplayName(String field) {
  final displayNames = {
    'amount': 'Amount',
    'paymentMethod': 'Payment Method',
    'userId': 'Member',
    'eventId': 'event',
    'monthId': 'Month',
    'isMonthlyContribution': 'type',
    'communityId': 'Community',
    'createdAt': 'Date',
    'addedBy': 'Added By',
    'addedByUserName': 'Added By',
  };
  
  if (displayNames.containsKey(field)) {
    return displayNames[field]!;
  }
  
  // Convert cnamelCase to Ttitle Case
  final buffer = StringBuffer();
  for (int i = 0; i < field.length; i++) {
    if (i > 0 && field[i] == field[i].toUpperCase()) {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? field[i].toUpperCase() : field[i]);
  }
  
  return buffer.toString();
}

Future<void> _generateReceiptFromContribution(Map<String, dynamic> contribution, AppAuthProvider _authProvider) async {
  if (!context.mounted) return;

  try {
    // 1. Convert to ContributionModel
    final contributionModel = _convertMapToContributionModel(contribution, _authProvider);
    
    // 2. Get user name
    final contributorName = await _getUserName(_authProvider.user?.uid ?? '');
    
    if (!mounted || !context.mounted) return;

    // 3. Now call the generator which will show its own progress dialog
    await ContributionReceiptImage.generateAndShowReceipt(
      context: context,
      contribution: contributionModel,
      contributorName: contributorName,
      name: contribution['EventTitle'] ?? 'Unknown event',
      communityName: contribution['communityName'], // Use the fixed field from service
    );

    debugPrint('✅ Receipt generation process completed');

  } catch (e, st) {
    debugPrint('Receipt error: $e\n$st');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate receipt: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

ContributionModel _convertMapToContributionModel(Map<String, dynamic> contribution, AppAuthProvider _authProvider) {
  // Debug: Print contribution data
  debugPrint('🔄 Converting contribution: ${contribution['contributionId']}');
  debugPrint('  isEdited value: ${contribution['isEdited']}');
  debugPrint('  editHistory: ${contribution['editHistory']}');
  
  return ContributionModel(
    contributionId: contribution['contributionId'] ?? '',
    eventId: contribution['eventId'] ?? '',
    userId: contribution['userId'] ?? _authProvider.user?.uid ?? '',
    contributorName: contribution['contributorName'] ?? _authProvider.user?.displayName ?? 'User',
    communityId: contribution['communityId'] ?? '',
    amount: (contribution['amount'] ?? 0).toDouble(),
    paymentMethod: contribution['paymentMethod'] ?? 'cash',
    isMonthlyContribution: contribution['isMonthlyContribution'] == true,
    monthId: contribution['monthId'],
    addedByUserId: contribution['addedByUserId'],
    addedByUserName: contribution['addedByUserName'],
    addedAt: contribution['addedAt'] is Timestamp ? contribution['addedAt'] as Timestamp : Timestamp.now(),
    
    // FIX: Better handling of isEdited
    isEdited: _getIsEditedStatus(contribution),
    
    lastEditedByUserId: contribution['lastEditedByUserId'],
    lastEditedByUserName: contribution['lastEditedByUserName'],
    lastEditedAt: contribution['lastEditedAt'] is Timestamp ? contribution['lastEditedAt'] as Timestamp : null,
    editReason: contribution['editReason'],
    editHistory: (contribution['editHistory'] is List) ? List<Map<String, dynamic>>.from(contribution['editHistory']) : [],
    createdAt: (contribution['createdAt'] is Timestamp) ? contribution['createdAt'] as Timestamp : Timestamp.now(),
  );
}

// Helper method to get user name
Future<String> _getUserName(String? userId) async {
  if (userId == null || userId.isEmpty) return 'User';
  
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      return userDoc.data()?['displayName'] ?? 
             userDoc.data()?['name'] ?? 
             userDoc.data()?['email']?.split('@').first ??
             'User $userId';
    }
    
    return 'User $userId';
  } catch (e) {
    debugPrint('Error fetching user name: $e');
    return 'User $userId';
  }
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
              'You haven\'t made any contributions yet. Start contributing to events to see them here!',
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

  // Helper method for payment method formatting
  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash': return 'Cash';
      case 'upi': return 'UPI';
      default: return method;
    }
  }
}







