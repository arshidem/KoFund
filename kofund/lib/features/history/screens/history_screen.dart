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
import '../providers/history_provider.dart';
import '../utils/contribution_receipt_pdf.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/skeleton/history_list_skeleton.dart';

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

  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController();

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
        print('🔄 DEBUG: Auto-refresh triggered after 3 seconds');
      }
    });
  }

  void _onRefresh() async {
    print('🔄 DEBUG: Pull to refresh triggered in History');
    
    try {
      final provider = Provider.of<HistoryProvider>(context, listen: false);
      await provider.refresh();
      
      _refreshController.refreshCompleted();
      
      if (mounted) {
        setState(() {});
      }
      print('✅ DEBUG: History refresh completed successfully');
    } catch (e) {
      _refreshController.refreshFailed();
      print('❌ DEBUG: History refresh failed: $e');
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
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
                        color: Colors.white.withOpacity(0.5),
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
            color: Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
              color: AppColors.primary(context).withOpacity(0.5)
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.primary(context).withOpacity(0.7),
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
            color: AppColors.primary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.primary(context).withOpacity(0.7),
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
      color: AppColors.primary(context).withOpacity(0.06),
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
              color: AppColors.primary(context).withOpacity(0.18),
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
      margin: const EdgeInsets.only(right: 12, left: 12, top: 12),
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
          color: AppColors.background(context).withOpacity(0.7),
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

  @override
  Widget build(BuildContext context) {
    final bool isContribution = item.type == HistoryItemType.contribution;
    final iconColor = isContribution ? AppColors.revenue(context) : AppColors.expense(context);
    final amountText = (isContribution ? '+ ' : '- ') + formatAmount(item.amount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
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
                  shape: BoxShape.circle,
                  color: isContribution 
                    ? AppColors.revenue(context).withOpacity(0.1)
                    : AppColors.expense(context).withOpacity(0.1),
                ),
                child: Icon(
                  isContribution ? Icons.arrow_upward : Icons.arrow_downward,
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

  const _BottomDetails({
    Key? key,
    required this.item,
    required this.currentUid,
    required this.communityLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
// In _BottomDetails widget, replace the Container with:
Center(
  child: Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AppColors.border(context),
      borderRadius: BorderRadius.circular(2),
    ),
  ),
),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          _buildDetailRow('Amount:', f.format(item.amount), context),
          _buildDetailRow('Date:', DateFormat.yMMMMd().add_jm().format(item.date), context),
          if (item.category != null) _buildDetailRow('Category:', item.category!, context),
          if (item.userId != null) _buildDetailRow('By:', item.subtitle, context),
          const SizedBox(height: 20),

          if (item.type == HistoryItemType.contribution && currentUid == item.userId)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt),
                onPressed: () => ContributionReceiptPdf.showPreview(
                  context,
                  item,
                  communityName: communityLabel,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: const Text("Get Receipt"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600, 
              color: AppColors.textSecondary(context)
            ),
          ),
          const SizedBox(width: 8),
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