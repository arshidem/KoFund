// lib/features/history/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/add_action_sheet.dart';
import '../widgets/add_contribution_modal.dart';
import '../widgets/add_expense_modal.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/contribution_service.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/services/program_service.dart';
import '../../../core/services/user_service.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../contributions/models/contribution_model.dart';
import '../../contributions/providers/contribution_provider.dart';
import '../../expenses/providers/expense_provider.dart';
import '../providers/history_provider.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/skeleton/history_list_skeleton.dart';
import 'edit_contribution_screen.dart';
import 'edit_expense_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/programs/utils/contribution_receipt_pdf.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class HistoryScreen extends StatelessWidget {
  final bool? forceBackButton; // Optional override for specific cases
  const HistoryScreen({
    super.key,
    this.forceBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    return ChangeNotifierProvider(
      create: (_) => HistoryProvider(
        contributionService: ContributionService(),
        expenseService: ExpenseService(),
        programService: ProgramService(),
        userService: UserService(),
        authProvider: auth,
      ),
child: _HistoryScreenBody(forceBackButton: forceBackButton),
    );
  }
}

class _HistoryScreenBody extends StatefulWidget {
  final bool? forceBackButton;

  const _HistoryScreenBody({Key? key, this.forceBackButton}) : super(key: key);

  @override
  State<_HistoryScreenBody> createState() => _HistoryScreenBodyState();
}

class _HistoryScreenBodyState extends State<_HistoryScreenBody> {
  String _formatTime(DateTime dt) => DateFormat.jm().format(dt);
  String _formatAmount(double amount) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount);
Map<String, String> _programNames = {};

  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // ✅ AUTO REFRESH AFTER 2 SECONDS
    _autoRefreshOnLoad();
  }

  // ✅ AUTO REFRESH METHOD
  void _autoRefreshOnLoad() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _onRefresh();
        debugPrint('🔄 DEBUG: Auto-refresh triggered after 3 seconds');
      }
    });
  }

  void _onRefresh() async {
    debugPrint('🔄 DEBUG: Pull to refresh triggered in History');
    
    try {
      final provider = Provider.of<HistoryProvider>(context, listen: false);
      await provider.refresh();
      
      _refreshController.refreshCompleted();
      
      if (mounted) {
        setState(() {});
      }
      debugPrint('✅ DEBUG: History refresh completed successfully');
    } catch (e) {
      _refreshController.refreshFailed();
      debugPrint('❌ DEBUG: History refresh failed: $e');
    }
  }
Future<void> _loadProgramName(String programId) async {
  if (_programNames.containsKey(programId)) return;
  
  try {
    final programDoc = await FirebaseFirestore.instance
        .collection('programs')
        .doc(programId)
        .get();
    
    if (programDoc.exists) {
      final name = programDoc.data()?['title'] ?? programDoc.data()?['name'] ?? 'Unknown';
      setState(() {
        _programNames[programId] = name;
      });
    }
  } catch (e) {
    debugPrint('Error loading program: $e');
  }
}
  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = Provider.of<HistoryProvider>(context, listen: false);
    provider.setSearchQuery(_searchController.text);
  }


  void _openFilterSheet(BuildContext context) {
    final provider = Provider.of<HistoryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FilterSheet(provider: provider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HistoryProvider>(context);
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final communityLabel = auth.user?.communityId ?? '';

    // 🏢 ENTERPRISE-GRADE BACK BUTTON DETECTION
    final bool showBackButton;
    
    if (widget.forceBackButton != null) {
      // Manual override if provided
      showBackButton = widget.forceBackButton!;
    } else {
      // Smart detection - preferred by large companies
      final route = ModalRoute.of(context);
      showBackButton = route?.canPop ?? false;
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      // 🎯 SMART APP BAR WITH BACK BUTTON DETECTION
    // 🎯 SMART APP BAR WITH BACK BUTTON DETECTION
appBar: AppBar(
    title: const Text(
    'Transaction History',
    style: TextStyle(
      color: Colors.white, // Moved style here
      fontSize: 18, // Add font size if needed
      fontWeight: FontWeight.w600, // Add font weight if needed
    ),
  ),
  centerTitle: true,
  leading: showBackButton 
      ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        )
      : null,
  automaticallyImplyLeading: showBackButton,
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white,
  elevation: 0,
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background(context),
    systemNavigationBarIconBrightness: Brightness.dark,
  ),
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
    ),
  ),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(50), // Changed from 70 to 50
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), // Changed from (8,4,8,8) to (8,8,8,8)
      child: _buildModernSearchBar(),
    ),
  ),
),
  body: SmartRefresher(
  controller: _refreshController,
  onRefresh: _onRefresh,
  enablePullDown: true,
  enablePullUp: false,
  physics: const BouncingScrollPhysics(),
  header: ClassicHeader(
    idleText: 'Pull down to refresh',
    releaseText: 'Release to refresh',
    refreshingText: 'Refreshing transactions...',
    completeText: 'Refresh complete',
    failedText: 'Refresh failed',
    idleIcon: Icon(Icons.arrow_downward, color: AppColors.textSecondary(context)),
    releaseIcon: Icon(Icons.arrow_upward, color: AppColors.primary(context)),
    refreshingIcon: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
      ),
    ),
    completeIcon: Icon(Icons.check, color: Colors.green),
    failedIcon: Icon(Icons.error, color: Colors.red),
  ),
  child: SafeArea(
    child: Column(
      children: [
        // FILTER TABS
        const _FilterTabs(),

        // SEARCH HEADER
        if (provider.searchQuery.isNotEmpty) _SearchHeader(provider: provider),

        // MAIN CONTENT
   // In your HistoryScreen, update the Expanded widget content:
Expanded(
  child: provider.isLoading && provider.items.isEmpty // ✅ Change filteredItems to items
      ? HistoryListSkeleton(
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        )
      : provider.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.refresh(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : provider.filteredItems.isEmpty
              ? _buildEmptyState(provider)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: provider.groupedByDate.length,
                  itemBuilder: (context, idx) {
                    final dateKey = provider.groupedByDate.keys.toList()[idx];
                    final items = provider.groupedByDate[dateKey]!;
                    return _DateGroup(
                      dateLabel: dateKey,
                      items: items,
                      formatTime: _formatTime,
                      formatAmount: _formatAmount,
                      communityLabel: communityLabel,
                    );
                  },
                ),
)
      ],
    ),
  ),
),
      // FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary(context),
        onPressed: () {
          // Show add action sheet
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => const AddActionSheet(),
          );
        },
        child: const Icon(Icons.add, size: 26, color: Colors.white),
      ),
    );
  }
Widget _buildModernSearchBar() {
  return Row(
    children: [
      Expanded(
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                children: [
                  // Search Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 0,
                      ),
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  
                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      cursorColor: Colors.white,
                      cursorWidth: 2,
                      cursorHeight: 20,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        hintText: 'Search transactions...',
                        hintStyle: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(right: 0),
                                child: Container(
                                  width: 32,
                                  height: 32,
                               
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      Provider.of<HistoryProvider>(context, listen: false)
                                          .setSearchQuery('');
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _searchController.text = value;
                        Provider.of<HistoryProvider>(context, listen: false).setSearchQuery(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      
      const SizedBox(width: 8),
      
      // Filter Icon
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          color: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openFilterSheet(context),
                child: const Center(
                  child: Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
  Widget _buildEmptyState(HistoryProvider provider) {
    if (provider.searchQuery.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: 1.0,
            child: Icon(
              Icons.search_off, 
              size: 64, 
              color: AppColors.primary(context).withValues(alpha: 0.5)
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.primary(context).withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'No matches for "${provider.searchQuery}"',
              style: TextStyle(
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                _searchController.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Clear Search'),
            ),
          ),
        ],
      );
    } else {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.primary(context).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.primary(context).withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'When contributions or expenses are added,\nthey will appear here.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
  }
}

class _SearchHeader extends StatelessWidget {
  final HistoryProvider provider;

  const _SearchHeader({Key? key, required this.provider}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary(context).withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: AppColors.primary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search results for "${provider.searchQuery}"',
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${provider.filteredItems.length} ${provider.filteredItems.length == 1 ? 'item' : 'items'}',
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== FILTER TABS ===================
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<HistoryProvider>(context);

    return Container(
      margin: const EdgeInsets.only(right: 12, left: 12, top: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _tab("All", p.filterType == HistoryFilterType.all,
              () => p.setFilter(HistoryFilterType.all), context),
          _tab("Contributions", p.filterType == HistoryFilterType.contributions,
              () => p.setFilter(HistoryFilterType.contributions), context),
          _tab("Expenses", p.filterType == HistoryFilterType.expenses,
              () => p.setFilter(HistoryFilterType.expenses), context),
        ],
      ),
    );
  }

  Widget _tab(String text, bool active, VoidCallback onTap, BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textPrimary(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
// =================== DATE GROUP ===================
class _DateGroup extends StatelessWidget {
  final String dateLabel;
  final List<HistoryItem> items;
  final String Function(DateTime) formatTime;
  final String Function(double) formatAmount;
  final String communityLabel;

  const _DateGroup({
    Key? key,
    required this.dateLabel,
    required this.items,
    required this.formatTime,
    required this.formatAmount,
    required this.communityLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUid = auth.user?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header - flat style like screenshot
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.background(context).withValues(alpha: 0.7),
          child: Text(
            dateLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        
        // List of transactions for this date
        Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isLastItem = index == items.length - 1;
            
            return Column(
              children: [
                _HistoryTile(
                  item: item,
                  formatTime: formatTime,
                  formatAmount: formatAmount,
                  currentUid: currentUid,
                  communityLabel: communityLabel,
                ),
                // Horizontal divider between transactions (except last one)
                if (!isLastItem) 
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border(context),
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// =================== TILE ===================
// =================== TILE ===================
// =================== TILE ===================
class _HistoryTile extends StatelessWidget {
  final HistoryItem item;
  final String Function(DateTime) formatTime;
  final String Function(double) formatAmount;
  final String? currentUid;
  final String communityLabel;

  const _HistoryTile({
    Key? key,
    required this.item,
    required this.formatTime,
    required this.formatAmount,
    required this.currentUid,
    required this.communityLabel,
  }) : super(key: key);

  Future<Map<String, dynamic>?> _fetchContributionData(String historyItemId) async {
    try {
      if (item.type != HistoryItemType.contribution) return null;
      
      debugPrint('🔍 DEBUG: HistoryItem ID: "$historyItemId"');
      
      // Try different patterns to find the actual document ID
      List<String> possibleDocIds = [];
      
      // Pattern 1: Remove "contrib_vwzl" prefix (12 chars)
      if (historyItemId.startsWith('contrib_vwzl')) {
        possibleDocIds.add(historyItemId.substring(12));
      }
      
      // Pattern 2: Remove "contrib_" prefix (8 chars)
      if (historyItemId.startsWith('contrib_')) {
        possibleDocIds.add(historyItemId.substring(8));
      }
      
      // Pattern 3: Try the ID as-is
      possibleDocIds.add(historyItemId);
      
      // Remove duplicates
      possibleDocIds = possibleDocIds.toSet().toList();
      
      debugPrint('🔄 Possible document IDs to try: $possibleDocIds');
      
      for (String docId in possibleDocIds) {
        try {
          debugPrint('🔄 Trying ID: "$docId"');
          final doc = await FirebaseFirestore.instance
              .collection('contributions')
              .doc(docId)
              .get();
          
          if (doc.exists) {
            debugPrint('✅ SUCCESS! Found contribution with ID: "$docId"');
            return doc.data();
          } else {
            debugPrint('❌ Not found with ID: "$docId"');
          }
        } catch (e) {
          debugPrint('⚠️ Error trying ID "$docId": $e');
        }
      }
      
      debugPrint('❌ All attempts failed to find contribution');
      return null;
      
    } catch (e) {
      debugPrint('❌ Error fetching contribution data: $e');
      return null;
    }
  }

  // ADD THIS NEW METHOD TO FETCH EXPENSE DATA
  Future<Map<String, dynamic>?> _fetchExpenseData(String historyItemId) async {
    try {
      if (item.type != HistoryItemType.expense) return null;
      
      debugPrint('🔍 DEBUG: Fetching expense data for ID: "$historyItemId"');
      
      // For expenses, try different patterns to find the actual document ID
      List<String> possibleDocIds = [];
      
      // Pattern 1: Remove "expense_" prefix (8 chars)
      if (historyItemId.startsWith('expense_')) {
        possibleDocIds.add(historyItemId.substring(8));
      }
      
      // Pattern 2: Try the ID as-is
      possibleDocIds.add(historyItemId);
      
      // Remove duplicates
      possibleDocIds = possibleDocIds.toSet().toList();
      
      debugPrint('🔄 Possible expense document IDs to try: $possibleDocIds');
      
      for (String docId in possibleDocIds) {
        try {
          debugPrint('🔄 Trying expense ID: "$docId"');
          final doc = await FirebaseFirestore.instance
              .collection('expenses')  // This should match your Firestore collection name
              .doc(docId)
              .get();
          
          if (doc.exists) {
            debugPrint('✅ SUCCESS! Found expense with ID: "$docId"');
            return doc.data();
          } else {
            debugPrint('❌ Expense not found with ID: "$docId"');
          }
        } catch (e) {
          debugPrint('⚠️ Error trying expense ID "$docId": $e');
        }
      }
      
      debugPrint('❌ All attempts failed to find expense');
      return null;
      
    } catch (e) {
      debugPrint('❌ Error fetching expense data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isContribution = item.type == HistoryItemType.contribution;
    final iconColor = isContribution ? AppColors.revenue(context) : AppColors.expense(context);
    final amountText = (isContribution ? '+ ' : '- ') + formatAmount(item.amount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          Map<String, dynamic>? itemData;
          
          if (isContribution) {
            // Fetch contribution data
            itemData = await _fetchContributionData(item.id);
          } else if (item.type == HistoryItemType.expense) {
            // Fetch expense data - THIS WAS MISSING!
            itemData = await _fetchExpenseData(item.id);
          }
          
          // Show bottom sheet
          showModalBottomSheet(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            context: context,
            builder: (_) {
              return _BottomDetails(
                item: item,
                currentUid: currentUid,
                communityLabel: communityLabel,
                itemData: itemData, // Pass the fetched data
              );
            },
          );
        },
        child: Container(

          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Leading icon (circular)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isContribution 
                    ? AppColors.revenue(context).withValues(alpha: 0.1)
                    : AppColors.expense(context).withValues(alpha: 0.1),
                ),
                child: Icon(
                  isContribution ? Icons.payments : Icons.receipt_long_outlined,
                  size: 20,
                  color: iconColor,
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
              
              // Time and amount (stacked vertically on right)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTime(item.date),
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
    );
  }
}

// =================== BOTTOM DETAILS ===================
class _BottomDetails extends StatelessWidget {
  final HistoryItem item;
  final String? currentUid;
  final String communityLabel;
  final Map<String, dynamic>? itemData;

  const _BottomDetails({
    Key? key,
    required this.item,
    required this.currentUid,
    required this.communityLabel,
    this.itemData,
  }) : super(key: key);

@override
Widget build(BuildContext context) {
  final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // Check if current user is admin
  final bool isAdmin = _checkIfAdmin(context);
  
  // Get expense status if it's an expense (MOVE THIS UP)
  String? expenseStatus;
  if (item.type == HistoryItemType.expense && itemData != null) {
    expenseStatus = (itemData!['status'] as String?)?.toLowerCase() ?? 'pending';
  }
  
  // Get receipt button - only for contributions by the contributor
  bool hasReceiptButton = false;
  if (item.type == HistoryItemType.contribution && itemData != null) {
    final contributorId = itemData?['userId'];
    hasReceiptButton = currentUid == contributorId;
  }

  // Check if three-dot menu should be shown
  final bool showThreeDotMenu = _shouldShowThreeDotMenu(context, item);

  return DraggableScrollableSheet(
    expand: false,
    snap: true,
    snapSizes: const [0.4, 0.6, 0.9],
    initialChildSize: 1.0,
    minChildSize: 0.4,
    maxChildSize: 1.0,
    builder: (context, scrollController) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header section (non-scrollable)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              child: _buildHeaderRow(
                context,
                f: f,
                item: item,
                expenseStatus: expenseStatus, // Now this variable exists
                showThreeDotMenu: showThreeDotMenu,
              ),
            ),

            // Thin divider
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.border(context)),

            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: _buildContent(
                    context,
                    f: f,
                    item: item,
                    isAdmin: isAdmin,
                  ),
                ),
              ),
            ),

            // Bottom buttons (non-scrollable)
            _buildBottomButtons(context, hasReceiptButton),
          ],
        ),
      );
    },
  );
}

// =================== HEADER ROW ===================
Widget _buildHeaderRow(
  BuildContext context, {
  required NumberFormat f,
  required HistoryItem item,
  required String? expenseStatus,
  required bool showThreeDotMenu,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
 
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border(context).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Title row with conditional three-dot menu
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.type == HistoryItemType.contribution ? 'Contribution' : 'Expense'} Details',
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('EEEE, MMMM dd • hh:mm a').format(item.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Show three-dot menu only if allowed
            if (showThreeDotMenu)
              _buildThreeDotMenu(context, item),
          ],
        ),
      ],
    ),
  );
}

  // =================== THREE-DOT MENU ===================
  Widget _buildThreeDotMenu(BuildContext context, HistoryItem item) {
    // Get current user
    final auth = context.read<AppAuthProvider>();
    final currentUserId = auth.user?.uid;
    final isAdmin = auth.user?.isAdmin == true;
    
    // Check if current user is the expense payer
    final bool isExpensePayer = item.type == HistoryItemType.expense && 
                                itemData != null && 
                                itemData!['paidBy'] == currentUserId;
    
    // Check permissions
    final bool canEdit = item.type == HistoryItemType.contribution
        ? isAdmin
        : (isAdmin || isExpensePayer);
    
    final bool canDelete = item.type == HistoryItemType.contribution
        ? isAdmin
        : (isAdmin || isExpensePayer);
    
    final bool canChangeStatus = item.type == HistoryItemType.expense && isAdmin;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: AppColors.textSecondary(context),
        size: 24,
      ),
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> menuItems = [];
        
        // Edit option
        if (canEdit) {
          menuItems.add(
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 20,
                    color: AppColors.primary(context),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.type == HistoryItemType.contribution 
                        ? 'Edit Contribution' 
                        : 'Edit Expense',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Delete option
        if (canDelete) {
          menuItems.add(
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete,
                    size: 20,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Status change options for expenses (admin only)
        if (canChangeStatus && item.type == HistoryItemType.expense) {
          menuItems.add(const PopupMenuDivider(height: 8));
          
          final currentStatus = (itemData?['status'] as String?)?.toLowerCase() ?? 'pending';
          
          // Pending status
          if (currentStatus != 'pending') {
            menuItems.add(
              PopupMenuItem<String>(
                value: 'status_pending',
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 20,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    const Text('Mark as Pending'),
                  ],
                ),
              ),
            );
          }
          
          // Approved status
          if (currentStatus != 'approved') {
            menuItems.add(
              PopupMenuItem<String>(
                value: 'status_approved',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    const Text('Mark as Approved'),
                  ],
                ),
              ),
            );
          }
          
          // Rejected status
          if (currentStatus != 'rejected') {
            menuItems.add(
              PopupMenuItem<String>(
                value: 'status_rejected',
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      size: 20,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    const Text('Mark as Rejected'),
                  ],
                ),
              ),
            );
          }
        }
        
        return menuItems;
      },
      onSelected: (String value) {
        if (value == 'edit') {
          _editItem(context, item);
        } else if (value == 'delete') {
          _deleteItem(context, item);
        } else if (value.startsWith('status_')) {
          final newStatus = value.split('_')[1];
          _changeExpenseStatus(context, item, newStatus);
        }
      },
    );
  }

// =================== CONTENT ===================
Widget _buildContent(
  BuildContext context, {
  required NumberFormat f,
  required HistoryItem item,
  required bool isAdmin,
}) {
  // Get expense status if it's an expense
  String? expenseStatus;
  if (item.type == HistoryItemType.expense && itemData != null) {
    expenseStatus = (itemData!['status'] as String?)?.toLowerCase() ?? 'pending';
  }
  
  // Get contributor/payer name based on item type
  final String? displayName = _getDisplayName(item);
  
  // Check if edited
  final bool isEdited = itemData?['isEdited'] == true;
  
  final title = (item.type == HistoryItemType.contribution && itemData != null)
        ? (itemData!['programName'] ?? item.title)
        : item.title;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Amount Card - NOW MOVED TO CONTENT (scrollable area)
      Container(
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
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  item.amount.toStringAsFixed(2),
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

            // Title/Program name
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Contributor/Payer info
            if (displayName != null && displayName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${item.type == HistoryItemType.contribution ? 'By:' : 'Paid by:'} $displayName',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary(context),
                ),
              ),
            ],

            // Status chips
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                // Type chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    item.type == HistoryItemType.contribution
                        ? 'CONTRIBUTION'
                        : 'EXPENSE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                // Edited badge
                if (isEdited)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 14, color: Colors.orange),
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

                // Expense status chip
                if (item.type == HistoryItemType.expense && expenseStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(expenseStatus).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _getStatusColor(expenseStatus).withValues(alpha: 0.3),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      expenseStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(expenseStatus),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // Basic Information Section
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
            // Get contributor/payer name based on item type
            if (_getDisplayName(item) != null) ...[
              _buildInfoRowMinimal(
                context,
                icon: item.type == HistoryItemType.contribution 
                    ? Icons.person_rounded 
                    : Icons.payments_rounded,
                label: item.type == HistoryItemType.contribution 
                    ? 'Contributor' 
                    : 'Paid By',
                value: _getDisplayName(item)!,
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 0.6,
                color: AppColors.border(context),
              ),
              const SizedBox(height: 12),
            ],

            // Added By (if available)
            if (itemData?['addedByUserName'] != null && itemData!['addedByUserName'].isNotEmpty)
              Column(
                children: [
                  _buildInfoRowMinimal(
                    context,
                    icon: Icons.person_add_rounded,
                    label: 'Added By',
                    value: itemData!['addedByUserName'],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: AppColors.border(context),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Payment Method (if available)
            if (itemData?['paymentMethod'] != null && itemData!['paymentMethod'].isNotEmpty)
              _buildInfoRowMinimal(
                context,
                icon: Icons.payment_rounded,
                label: 'Payment Method',
                value: _formatPaymentMethod(itemData!['paymentMethod']),
              ),

            // Category (for expenses)
            if (item.type == HistoryItemType.expense && itemData?['category'] != null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: AppColors.border(context),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRowMinimal(
                    context,
                    icon: _getCategoryIcon(itemData!['category']),
                    label: 'Category',
                    value: itemData!['category'].toString().toUpperCase(),
                  ),
                ],
              ),

            // Description (if available)
            if (itemData?['description'] != null && itemData!['description'].isNotEmpty)
              Column(
                children: [
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: AppColors.border(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    itemData!['description'],
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),

      // Edit History Section
      if (itemData != null && itemData!['editHistory'] != null)
        _buildEditHistorySection(context),

      // Bottom spacing
      const SizedBox(height: 40),
    ],
  );
}


// Updated Expense Status Chip
Widget _buildExpenseStatusChip(String status) {
  final Color backgroundColor;
  final Color textColor;
  final String label;
  final IconData icon;

  switch (status) {
    case 'approved':
      backgroundColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      label = 'Approved';
      icon = Icons.check_circle;
      break;
    case 'rejected':
      backgroundColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      label = 'Rejected';
      icon = Icons.cancel;
      break;
    case 'pending':
    default:
      backgroundColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      label = 'Pending';
      icon = Icons.schedule;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: textColor.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: textColor,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionHeader(BuildContext context, {required String title, required IconData icon}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary(context).withValues(alpha: 0.10),
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
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
    ],
  );
}

Widget _buildInfoRowMinimal(BuildContext context, {required IconData icon, required String label, required String value}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 18,
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
                fontSize: 11,
                color: AppColors.textTertiary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
Widget _buildEditHistorySection(BuildContext context) {
  final editHistory = (itemData!['editHistory'] as List<dynamic>?) ?? [];
  if (editHistory.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Divider(
        thickness: 0.6,
        color: AppColors.border(context),
      ),
      const SizedBox(height: 20),

      // Header
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

      // Edit History Items
      const SizedBox(height: 20),
      ...editHistory.map((edit) => _buildEditHistoryItem(edit, context)).toList(),
    ],
  );
}


  Widget _buildExpenseInfo(BuildContext context) {
    final description = itemData?['description']?.toString();
    if (description == null || description.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description,
                size: 14,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'Description:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 22),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaidByInfo(BuildContext context) {
    return FutureBuilder<String>(
      future: _getPaidByName(itemData!['paidBy'] ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDetailRow('Paid By:', 'Loading...', context);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildDetailRow('Paid By:', 'Unknown', context);
        }
        return _buildDetailRow('Paid By:', snapshot.data!, context);
      },
    );
  }

  Widget _buildExpenseStatusChangeButton(BuildContext context, HistoryItem item, String currentStatus) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change Status:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _changeExpenseStatus(context, item, 'pending'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: currentStatus == 'pending' ? Colors.orange : Colors.grey,
                    side: BorderSide(
                      color: currentStatus == 'pending' ? Colors.orange : Colors.grey,
                    ),
                  ),
                  child: const Text('Pending'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _changeExpenseStatus(context, item, 'approved'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: currentStatus == 'approved' ? Colors.green : Colors.grey,
                    side: BorderSide(
                      color: currentStatus == 'approved' ? Colors.green : Colors.grey,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _changeExpenseStatus(context, item, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: currentStatus == 'rejected' ? Colors.red : Colors.grey,
                    side: BorderSide(
                      color: currentStatus == 'rejected' ? Colors.red : Colors.grey,
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =================== CONTRIBUTION SPECIFIC WIDGETS ===================

  Widget _buildDataMissingWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Contribution details not available for editing',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryInfo(BuildContext context) {
    String? addedBy;
    String? addedAt;
    
    if (item.type == HistoryItemType.contribution) {
      addedBy = itemData?['addedByUserName'] ?? itemData?['addedByUserId'];
      final addedAtTimestamp = itemData?['addedAt'] as Timestamp?;
      addedAt = addedAtTimestamp != null 
          ? DateFormat('MMM dd, yyyy hh:mm a').format(addedAtTimestamp.toDate())
          : null;
    } else if (item.type == HistoryItemType.expense) {
      addedBy = itemData?['addedByUserName'] ?? itemData?['addedByUserId'];
      final addedAtTimestamp = itemData?['addedAt'] as Timestamp?;
      addedAt = addedAtTimestamp != null 
          ? DateFormat('MMM dd, yyyy hh:mm a').format(addedAtTimestamp.toDate())
          : null;
    }
    
    if (addedBy == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_alt_1,
                size: 14,
                color: AppColors.primary(context),
              ),
              const SizedBox(width: 8),
              Text(
                'Added by: $addedBy',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          if (addedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 22),
              child: Text(
                'On: $addedAt',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditInfo(BuildContext context) {
    // For contributions
    if (item.type == HistoryItemType.contribution) {
      final isEdited = itemData?['isEdited'] == true;
      final lastEditedBy = itemData?['lastEditedByUserName'] ?? itemData?['lastEditedByUserId'];
      final editReason = itemData?['editReason'];
      
      if (!isEdited) return const SizedBox.shrink();
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 14,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edited',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                if (lastEditedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'by $lastEditedBy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
            if (editReason != null && editReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  'Reason: $editReason',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    // For expenses
    else if (item.type == HistoryItemType.expense && itemData != null) {
      final isEdited = itemData?['isEdited'] == true;
      final lastEditedBy = itemData?['lastEditedByUserName'] ?? itemData?['lastEditedByUserId'];
      final editReason = itemData?['editReason'];
      
      if (!isEdited) return const SizedBox.shrink();
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 14,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edited',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                if (lastEditedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'by $lastEditedBy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
            if (editReason != null && editReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  'Reason: $editReason',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildProgramName(BuildContext context) {
    return FutureBuilder<String>(
      future: _getProgramName(context, itemData!['programId']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDetailRow('Program:', 'Loading...', context);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildDetailRow('Program:', 'Unknown Program', context);
        }
        return _buildDetailRow('Program:', snapshot.data!, context);
      },
    );
  }

  Widget _buildEditHistory(BuildContext context) {
    // Get edit history based on item type
    List<dynamic> editHistory = [];
    
    if (item.type == HistoryItemType.contribution) {
      editHistory = (itemData?['editHistory'] as List<dynamic>?) ?? [];
    } else if (item.type == HistoryItemType.expense) {
      editHistory = (itemData?['editHistory'] as List<dynamic>?) ?? [];
    }
    
    if (editHistory.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: [
        const SizedBox(height: 16),
        Divider(
          color: AppColors.border(context),
          height: 1,
        ),
        const SizedBox(height: 12),
        Text(
          'Edit History',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        ...editHistory.map((edit) => _buildEditHistoryItem(edit, context)).toList(),
      ],
    );
  }
Widget _buildExpenseStatusChangeButtons(BuildContext context, HistoryItem item, String currentStatus) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Divider(
        thickness: 0.6,
        color: AppColors.border(context),
      ),
      const SizedBox(height: 20),

      // Header
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings,
              size: 20,
              color: AppColors.primary(context),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Status Management',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),

      const SizedBox(height: 16),

      // Buttons
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _changeExpenseStatus(context, item, 'pending'),
              style: OutlinedButton.styleFrom(
                foregroundColor: currentStatus == 'pending' ? Colors.orange : AppColors.textSecondary(context),
                side: BorderSide(
                  color: currentStatus == 'pending' ? Colors.orange : AppColors.border(context),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: currentStatus == 'pending' ? Colors.orange : AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontWeight: currentStatus == 'pending' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _changeExpenseStatus(context, item, 'approved'),
              style: OutlinedButton.styleFrom(
                foregroundColor: currentStatus == 'approved' ? Colors.green : AppColors.textSecondary(context),
                side: BorderSide(
                  color: currentStatus == 'approved' ? Colors.green : AppColors.border(context),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: currentStatus == 'approved' ? Colors.green : AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Approve',
                    style: TextStyle(
                      fontWeight: currentStatus == 'approved' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _changeExpenseStatus(context, item, 'rejected'),
              style: OutlinedButton.styleFrom(
                foregroundColor: currentStatus == 'rejected' ? Colors.red : AppColors.textSecondary(context),
                side: BorderSide(
                  color: currentStatus == 'rejected' ? Colors.red : AppColors.border(context),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cancel,
                    size: 18,
                    color: currentStatus == 'rejected' ? Colors.red : AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reject',
                    style: TextStyle(
                      fontWeight: currentStatus == 'rejected' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
Widget _buildEditHistoryItem(Map<String, dynamic> edit, BuildContext context) {
  final editedAt = (edit['editedAt'] as Timestamp?)?.toDate();
  final editedBy = edit['editedByUserName'] ?? edit['editedByUserId'] ?? 'Unknown';
  final changes = (edit['changes'] as Map<String, dynamic>?) ?? {};
  final reason = edit['reason'];

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
        // Date and User
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

        // Change lines
        ...changes.entries.map((fieldChange) {
          final fieldName = _getFieldDisplayName(fieldChange.key);
          final change = fieldChange.value as Map<String, dynamic>;
          final oldValue = change['old']?.toString();
          final newValue = change['new']?.toString();

          return Padding(
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
                    text: '$fieldName: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (oldValue != null)
                    TextSpan(
                      text: oldValue,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (oldValue != null && newValue != null)
                    const TextSpan(text: '  →  '),
                  if (newValue != null)
                    const TextSpan(
                      text: '',
                    ),
                  if (newValue != null)
                    TextSpan(
                      text: newValue,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),

        // Reason
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
String _formatPaymentMethod(String method) {
  final lowerMethod = method.toLowerCase();
  switch (lowerMethod) {
    case 'cash':
      return 'Cash';
    case 'bank_transfer':
    case 'bank transfer':
      return 'Bank Transfer';
    case 'upi':
      return 'UPI';
    case 'credit_card':
    case 'credit card':
      return 'Credit Card';
    case 'debit_card':
    case 'debit card':
      return 'Debit Card';
    default:
      return method;
  }
}

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    case 'pending':
    default:
      return Colors.orange;
  }
}

IconData _getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant;
    case 'transport':
      return Icons.directions_car;
    case 'materials':
      return Icons.inventory;
    case 'venue':
      return Icons.place;
    case 'equipment':
      return Icons.build;
    default:
      return Icons.category;
  }
}

String _getFieldDisplayName(String field) {
  final fieldMap = {
    'amount': 'Amount',
    'paymentMethod': 'Payment Method',
    'userId': 'Member',
    'programId': 'Program',
    'title': 'Title',
    'description': 'Description',
    'category': 'Category',
    'vendorName': 'Vendor',
    'status': 'Status',
    'note': 'Note',
    'monthId': 'Month',
  };
  return fieldMap[field] ?? field;
}
 // Get display name based on item type
  String? _getDisplayName(HistoryItem item) {
    if (item.type == HistoryItemType.contribution) {
      // For contributions, use contributorName from ContributionModel
      return itemData?['contributorName'] ??
             itemData?['userName'] ??
             itemData?['displayName'] ??
             item.subtitle;
    } else {
      // For expenses, use paidByName from ExpenseModel
      return itemData?['paidByName'] ??
             itemData?['paidByUserName'] ??
             item.subtitle;
    }
  }

  // =================== COMMON WIDGETS ===================
Future<void> _generateReceipt(HistoryItem item, BuildContext context) async {
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    // First, get the program name
    String programName = 'Program';
    if (itemData != null && itemData!['programId'] != null) {
      programName = await _getProgramName(context, itemData!['programId']);
    } else {
      programName = item.title; // Fallback to item title
    }

    // Get contributor name
    String contributorName = 'User';
    if (itemData != null && itemData!['userId'] != null) {
      // You need to implement this method or use existing one
      contributorName = await _getUserName(itemData!['userId'], context);
    } else {
      contributorName = item.subtitle ?? 'User'; // Fallback to subtitle
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    // Convert HistoryItem to ContributionModel
    final contribution = _historyItemToContributionModel(item, itemData);

    // Generate and show receipt
    await ContributionReceiptPdf.generateAndShowReceipt(
      context: context,
      contribution: contribution,
      contributorName: contributorName,
      programName: programName,
      // communityName can be added here if you have it
    );

  } catch (e, st) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

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
   Widget _buildBottomButtons(BuildContext context, bool hasReceiptButton) {
    return Container(
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
          if (hasReceiptButton)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ElevatedButton(
                  onPressed: () {
                    _generateReceipt(item, context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
    );
  }

 bool _shouldShowThreeDotMenu(BuildContext context, HistoryItem item) {
    final auth = context.read<AppAuthProvider>();
    final isAdmin = auth.user?.isAdmin == true;
    final currentUserId = auth.user?.uid;
    
    if (item.type == HistoryItemType.contribution) {
      // For contributions: only show if user is admin
      return isAdmin;
    } else if (item.type == HistoryItemType.expense) {
      // For expenses: show if user is admin OR is the expense payer
      final isExpensePayer = itemData != null && 
                           itemData!['paidBy'] == currentUserId;
      return isAdmin || isExpensePayer;
    }
    
    return false;
  }
// Add this method to get user name
Future<String> _getUserName(String userId, BuildContext context) async {
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
  Widget _buildReceiptButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.receipt),
           onPressed: () {
  _generateReceipt(item, context); // Show receipt

},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary(context),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      label: const Text(
        "Get Receipt",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  // Convert HistoryItem to ContributionModel
  ContributionModel _historyItemToContributionModel(HistoryItem item, Map<String, dynamic>? itemData) {
    return ContributionModel(
      contributionId: item.id,
      programId: itemData?['programId'] ?? '',
      userId: itemData?['userId'] ?? '',
      contributorName: itemData?['contributorName'] ?? '', // Use contributorName field
      communityId: itemData?['communityId'] ?? '',
      amount: item.amount,
      paymentMethod: itemData?['paymentMethod'] ?? 'cash',
      isMonthlyContribution: itemData?['isMonthlyContribution'] ?? false,
      monthId: itemData?['monthId'],
      addedByUserId: itemData?['addedByUserId'],
      addedByUserName: itemData?['addedByUserName'],
      addedAt: itemData?['addedAt'] != null ? 
          (itemData!['addedAt'] is Timestamp ? itemData!['addedAt'] : Timestamp.now()) : 
          Timestamp.now(),
      isEdited: itemData?['isEdited'] ?? false,
      lastEditedByUserId: itemData?['lastEditedByUserId'],
      lastEditedByUserName: itemData?['lastEditedByUserName'],
      lastEditedAt: itemData?['lastEditedAt'] != null ? 
          (itemData!['lastEditedAt'] is Timestamp ? itemData!['lastEditedAt'] : Timestamp.now()) : 
          null,
      editReason: itemData?['editReason'],
      editHistory: (itemData?['editHistory'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      createdAt: itemData?['createdAt'] != null ? 
          (itemData!['createdAt'] is Timestamp ? itemData!['createdAt'] : Timestamp.fromDate(item.date)) : 
          Timestamp.fromDate(item.date),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                color: AppColors.textSecondary(context)
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
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

  // =================== ACTION METHODS ===================

  void _editItem(BuildContext context, HistoryItem item) {
    if (item.type == HistoryItemType.contribution) {
      _editContribution(context, item);
    } else if (item.type == HistoryItemType.expense) {
      _editExpense(context, item);
    }
  }

  // =================== EXPENSE ACTIONS ===================

  void _editExpense(BuildContext context, HistoryItem item) {
    debugPrint('🎯 Edit expense button pressed for item: ${item.id}');
    
    try {
      debugPrint('🔄 Navigating to edit expense screen...');
      
      String firestoreId = item.id;
      if (firestoreId.startsWith('expense_')) {
        firestoreId = firestoreId.substring(8); // Remove 'expense_' prefix
        debugPrint('   🔄 Removed "expense_" prefix');
        debugPrint('   🔍 Real Firestore ID: $firestoreId');
      }
      
      // Show loading indicator while fetching
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // First, fetch the expense to ensure it exists
      final expenseProvider = context.read<ExpenseProvider>();
      
      expenseProvider.getExpenseById(firestoreId).then((expense) {
        Navigator.pop(context); // Close loading dialog
        
        if (expense == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense not found'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        // Navigate to edit expense screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditExpenseScreen(
              expenseId: firestoreId,
              onSave: (updatedExpense) async {
                try {
                  debugPrint('💾 Saving updated expense...');
                  
                  if (updatedExpense == null) {
                    debugPrint('   ⚠️ Update cancelled or no changes');
                    return;
                  }
                  
                  final authProvider = context.read<AppAuthProvider>();
                  final currentUser = authProvider.user;
                  
                  if (currentUser == null) {
                    throw Exception('User not authenticated');
                  }
                  
                  debugPrint('👤 Current user: ${currentUser.uid}');
                  
                  await expenseProvider.updateExpense(
                    updatedExpense,
                    editedByUserId: currentUser.uid,
                    editedByUserName: currentUser.displayName ?? 'Admin',
                    editReason: updatedExpense.editReason,
                  );
                  
                  debugPrint('✅ Expense updated successfully');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense updated successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  
                } catch (e) {
                  debugPrint('❌ Error updating expense: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ),
        ).then((_) {
          debugPrint('🏁 Edit expense screen closed');
        });
      }).catchError((e) {
        Navigator.pop(context); // Close loading dialog
        debugPrint('❌ Error fetching expense: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      });
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error navigating to edit expense screen: $e');
      debugPrint('📌 Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening edit screen: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _changeExpenseStatus(BuildContext context, HistoryItem item, String newStatus) async {
    try {
      // Clean the expense ID if needed
      String expenseId = item.id;
      if (expenseId.startsWith('expense_')) {
        expenseId = expenseId.substring(8);
      }
      
      // Use ExpenseProvider to update status
      final expenseProvider = context.read<ExpenseProvider>();
      await expenseProvider.updateExpenseStatus(expenseId, newStatus);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense status changed to ${newStatus.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Close bottom sheet
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
    } catch (e) {
      debugPrint('Error changing expense status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =================== CONTRIBUTION ACTIONS ===================

  void _editContribution(BuildContext context, HistoryItem item) {
    debugPrint('🎯 Edit button pressed for item: ${item.id}');
    debugPrint('📊 itemData exists: ${itemData != null}');
    
    if (itemData == null) {
      debugPrint('❌ itemData is null!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit: Contribution data not found'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      debugPrint('🔄 Navigating to edit screen with ID only...');
      
      String firestoreId = item.id;
      if (firestoreId.startsWith('contrib_')) {
        firestoreId = firestoreId.substring(8);
        debugPrint('   🔄 Removed "contrib_" prefix');
        debugPrint('   🔍 Real Firestore ID: $firestoreId');
    }
    
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditContributionScreen(
            contributionId: firestoreId,
            onSave: (updatedContribution) async {
              try {
                debugPrint('💾 Saving updated contribution...');
                
                if (updatedContribution == null) {
                  debugPrint('   ⚠️ Update cancelled or no changes');
                  return;
                }
                
                final authProvider = context.read<AppAuthProvider>();
                final currentUser = authProvider.user;
                
                if (currentUser == null) {
                  throw Exception('User not authenticated');
                }
                
                debugPrint('👤 Current user: ${currentUser.uid}');
                
                final provider = context.read<ContributionProvider>();
                await provider.updateContribution(
                  updatedContribution,
                  editedByUserId: currentUser.uid,
                  editedByUserName: currentUser.displayName ?? 'Admin',
                  editReason: updatedContribution.editReason,
                );
                
                debugPrint('✅ Contribution updated successfully');
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contribution updated successfully'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
                
                if (Navigator.canPop(context)) Navigator.pop(context);
                if (Navigator.canPop(context)) Navigator.pop(context);
                
              } catch (e) {
                debugPrint('❌ Error updating contribution: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ),
      ).then((_) {
        debugPrint('🏁 Edit screen closed');
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error navigating to edit screen: $e');
      debugPrint('📌 Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening edit screen: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // =================== COMMON ACTIONS ===================

Future<void> _deleteItem(BuildContext context, HistoryItem item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: Text(
        'Are you sure you want to delete this ${item.type == HistoryItemType.contribution ? 'contribution' : 'expense'}? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      if (item.type == HistoryItemType.contribution) {
        // For contributions: Clean the ID if needed
        String contributionId = item.id;
        
        // DEBUG: Check what ID we have
        debugPrint('🔍 Original contribution ID from item: $contributionId');
        
        // Check if we need to clean the ID
        if (contributionId.startsWith('contrib_')) {
          contributionId = contributionId.substring(8); // Remove 'contrib_' prefix
          debugPrint('🔄 Cleaned contribution ID: $contributionId');
        }
        
        final provider = context.read<ContributionProvider>();
        
        // ✅ FIX: Ask for delete reason
        final reason = await _showDeleteReasonDialog(context, 'contribution');
        if (reason == null) return; // User cancelled
        
        // ✅ FIX: Now call with 2 parameters
        await provider.deleteContribution(contributionId, reason);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribution deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
      } else if (item.type == HistoryItemType.expense) {
        // For expenses: Clean the ID if needed
        String expenseId = item.id;
        
        // DEBUG: Check what ID we have
        debugPrint('🔍 Original expense ID from item: $expenseId');
        
        // Check if we need to clean the ID
        if (expenseId.startsWith('expense_')) {
          expenseId = expenseId.substring(8); // Remove 'expense_' prefix
          debugPrint('🔄 Cleaned expense ID: $expenseId');
        }
        
        final expenseProvider = context.read<ExpenseProvider>();
        await expenseProvider.deleteExpense(expenseId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Close bottom sheet
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
    } catch (e) {
      debugPrint('❌ Error deleting item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ✅ ADD THIS HELPER METHOD
Future<String?> _showDeleteReasonDialog(BuildContext context, String itemType) async {
  final reasonController = TextEditingController();
  
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $itemType'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please provide a reason for deleting this $itemType:'),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter reason...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = reasonController.text.trim();
            Navigator.pop(context, reason.isNotEmpty ? reason : 'Deleted from history screen');
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

  // =================== HELPER METHODS ===================

  Future<String> _getProgramName(BuildContext context, String programId) async {
    if (programId.isEmpty) return 'Unknown Program';
    
    try {
      // Try main programs collection first
      final programDoc = await FirebaseFirestore.instance
          .collection('programs')
          .doc(programId)
          .get();
      
      if (programDoc.exists) {
        return programDoc.data()?['title'] ?? programDoc.data()?['name'] ?? 'Unknown Program';
      }
      
      // Try community programs if communityId is available
      if (itemData != null && itemData!['communityId'] != null) {
        final communityProgramDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(itemData!['communityId'])
            .collection('programs')
            .doc(programId)
            .get();
        
        if (communityProgramDoc.exists) {
          return communityProgramDoc.data()?['title'] ?? communityProgramDoc.data()?['name'] ?? 'Unknown Program';
        }
      }
      
      return 'Program $programId';
    } catch (e) {
      debugPrint('Error fetching program name: $e');
      return 'Unknown Program';
    }
  }

  Future<String> _getPaidByName(String userId) async {
    if (userId.isEmpty) return 'Unknown User';
    
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
      debugPrint('Error fetching paid by user name: $e');
      return 'User $userId';
    }
  }

  String _formatExpenseStatus(String status) {
    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'approved': return 'Approved';
      case 'pending': return 'Pending Review';
      case 'rejected': return 'Rejected';
      case 'paid': return 'Paid';
      case 'unpaid': return 'Unpaid';
      default: return status;
    }
  }

  String _formatFieldName(String field) {
    final fieldMap = {
      'amount': 'Amount',
      'paymentMethod': 'Payment Method',
      'userId': 'Member',
      'programId': 'Program',
      'note': 'Note',
      'monthId': 'Month',
      // Expense specific fields
      'title': 'Title',
      'description': 'Description',
      'category': 'Category',
      'vendorName': 'Vendor',
      'referenceNumber': 'Reference Number',
      'program': 'Program', // For expense changes where program is stored as 'program'
    };
    return fieldMap[field] ?? field;
  }

  bool _checkIfAdmin(BuildContext context) {
    final auth = context.read<AppAuthProvider>();
    final user = auth.user;
    return user?.isAdmin == true;
  }

  bool _checkIfCurrentUserPaidBy(BuildContext context, HistoryItem item) {
    final auth = context.read<AppAuthProvider>();
    final currentUserId = auth.user?.uid;
    
    if (item.type == HistoryItemType.expense && 
        itemData != null && 
        currentUserId != null) {
      final paidById = itemData!['paidBy'];
      return paidById == currentUserId;
    }
    
    return false;
  }
}





// =================== FILTER SHEET ===================
class FilterSheet extends StatefulWidget {
  final HistoryProvider provider;
  const FilterSheet({Key? key, required this.provider}) : super(key: key);

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String? _selectedProgramId;

  @override
  void initState() {
    super.initState();
    _selectedProgramId = widget.provider.selectedProgramId;
  }

  List<DropdownMenuItem<String>> _getProgramMenuItems() {
    final programs = <String, String>{};

    for (final item in widget.provider.items) {
      if (item.programId != null && item.programId!.isNotEmpty) {
        programs[item.programId!] = item.title;
      }
    }

    final menuItems = programs.entries.map((entry) {
      return DropdownMenuItem<String>(
        value: entry.key,
        child: Text(
          entry.value,
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
      );
    }).toList();

    menuItems.insert(0, DropdownMenuItem<String>(
      value: null,
      child: Text(
        'All Programs', 
        style: TextStyle(color: AppColors.textSecondary(context))
      ),
    ));

    return menuItems;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final programMenuItems = _getProgramMenuItems();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: _selectedProgramId,
            decoration: InputDecoration(
              labelText: "Program",
              labelStyle: TextStyle(color: AppColors.primary(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary(context), width: 2),
              ),
            ),
            items: programMenuItems,
            onChanged: (val) {
              setState(() {
                _selectedProgramId = val;
              });
              p.setProgramFilter(val);
            },
          ),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: p.startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setState(() {});
                    p.setDateRange(d, p.endDate);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    labelStyle: TextStyle(color: AppColors.primary(context)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                    ),
                  ),
                  child: Text(
                    p.startDate != null ? DateFormat.yMMMd().format(p.startDate!) : 'Select',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: p.endDate ?? DateTime.now(),
                    firstDate: p.startDate ?? DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setState(() {});
                    p.setDateRange(p.startDate, d);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    labelStyle: TextStyle(color: AppColors.primary(context)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                    ),
                  ),
                  child: Text(
                    p.endDate != null ? DateFormat.yMMMd().format(p.endDate!) : 'Select',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    p.clearFilters();
                    setState(() {
                      _selectedProgramId = null;
                    });
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary(context),
                    side: BorderSide(color: AppColors.primary(context)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Clear Filters"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Apply"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}


