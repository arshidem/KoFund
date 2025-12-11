import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'dart:ui';
class ApprovalRequestsScreen extends StatefulWidget {
  const ApprovalRequestsScreen({super.key});

  @override
  State<ApprovalRequestsScreen> createState() => _ApprovalRequestsScreenState();
}

class _ApprovalRequestsScreenState extends State<ApprovalRequestsScreen> {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadMembers() async {
    final authProvider = context.read<AppAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final communityId = authProvider.user?.communityId;

    if (communityId != null) {
      await userProvider.loadCommunityMembers(communityId);
    }
  }

  void _onRefresh() async {
    try {
      await _loadMembers();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  // Helper method to show remove confirmation
  Future<bool?> _showRemoveConfirmation(BuildContext context, UserModel user) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Are you sure you want to remove ${user.displayName ?? "this user"} from approved members?',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to show reject confirmation
  Future<bool?> _showRejectConfirmation(BuildContext context, UserModel user) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User?'),
        content: Text(
          'Are you sure you want to reject ${user.displayName ?? "this user"}? This action cannot be undone.',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Filter members based on search query
  List<UserModel> _filterMembers(List<UserModel> members, String query) {
    if (query.isEmpty) return members;
    
    return members.where((user) {
      final name = user.displayName?.toLowerCase() ?? '';
      final email = user.email.toLowerCase();
      final searchTerm = query.toLowerCase();
      
      return name.contains(searchTerm) || email.contains(searchTerm);
    }).toList();
  }

  Widget _buildModernSearchBar() {
    return Row(
      children: [
        // Search Bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.card(context).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Search Icon with Glass Morphism
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        bottomLeft: Radius.circular(28),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary(context).withOpacity(0.3),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              bottomLeft: Radius.circular(28),
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary(context).withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.search,
                            color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    
                    // Text Field
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                          letterSpacing: 0.5,
                        ),
                        cursorColor: AppColors.primary(context),
                        cursorWidth: 2,
                        cursorHeight: 18,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 5),
                          hintText: 'Search members...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary(context).withOpacity(0.7),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.close, 
                                      size: 18, 
                                      color: Theme.of(context).appBarTheme.foregroundColor ?? AppColors.textPrimary(context)
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(int resultCount, String section) {
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
              'Search results for "$_searchQuery" in $section',
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
              '$resultCount ${resultCount == 1 ? 'member' : 'members'}',
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

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final authProvider = context.read<AppAuthProvider>();
    final communityId = authProvider.user?.communityId;

    if (communityId == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: Text(
            'No community found.',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Apply search filter
    final filteredPending = _filterMembers(userProvider.pendingMembers, _searchQuery);
    final filteredApproved = _filterMembers(userProvider.approvedMembers, _searchQuery);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Community Members'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
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
          refreshingText: 'Refreshing members...',
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
        child: CustomScrollView(
          slivers: [
            // Search Results Header (if searching)
            if (_searchQuery.isNotEmpty && (filteredPending.isNotEmpty || filteredApproved.isNotEmpty))
              SliverToBoxAdapter(
                child: _buildSearchHeader(filteredPending.length + filteredApproved.length, 'all members'),
              ),

            // Pending Approvals Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.border(context),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Pending Approvals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.border(context),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (filteredPending.isEmpty && _searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'No pending members found',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (filteredPending.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: AppColors.primary(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No pending members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context).withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All members are approved',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = filteredPending[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: _MemberCard(
                        user: user,
                        provider: userProvider,
                        communityId: communityId,
                        isApproved: false,
                        onApprove: () async {
                          await userProvider.approveUser(user.uid, communityId);
                          SnackbarHelper.showSuccess(context, 'User approved');
                          await userProvider.loadCommunityMembers(communityId);
                        },
                        onReject: () async {
                          final confirmed = await _showRejectConfirmation(context, user);
                          if (confirmed == true) {
                            await userProvider.rejectUser(user.uid);
                            SnackbarHelper.showInfo(context, 'User rejected');
                            await userProvider.loadCommunityMembers(communityId);
                          }
                        },
                      ),
                    );
                  },
                  childCount: filteredPending.length,
                ),
              ),

            // Approved Members Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.border(context),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Approved Members',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.border(context),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (filteredApproved.isEmpty && _searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'No approved members found',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (filteredApproved.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_add,
                        size: 48,
                        color: AppColors.primary(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No approved members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context).withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Approve members to see them here',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = filteredApproved[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: _MemberCard(
                        user: user,
                        provider: userProvider,
                        communityId: communityId,
                        isApproved: true,
                        onRemove: () async {
                          final confirmed = await _showRemoveConfirmation(context, user);
                          if (confirmed == true) {
                            await userProvider.unapproveUser(user.uid);
                            SnackbarHelper.showInfo(context, 'User removed');
                            await userProvider.loadCommunityMembers(communityId);
                          }
                        },
                      ),
                    );
                  },
                  childCount: filteredApproved.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final UserModel user;
  final UserProvider provider;
  final String communityId;
  final bool isApproved;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.user,
    required this.provider,
    required this.communityId,
    required this.isApproved,
    this.onApprove,
    this.onReject,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: AppColors.card(context),
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Optional: Add member details view
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with status indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isApproved 
                          ? AppColors.primary(context).withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      child: Text(
                        user.displayName?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isApproved 
                              ? AppColors.primary(context)
                              : Colors.orange,
                        ),
                      ),
                    ),
                    if (!isApproved)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.card(context),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // User Info - REMOVED THE STATUS TEXT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ❌ REMOVED: Status text ("Approved" / "Pending Approval")
                    ],
                  ),
                ),
                
                // Action Buttons
                Wrap(
                  spacing: 4,
                  children: [
                    if (!isApproved) ...[
                      // Approve Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.check, size: 20),
                          color: Colors.green,
                          tooltip: 'Approve',
                          onPressed: onApprove,
                        ),
                      ),
                      // Reject Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.red,
                          tooltip: 'Reject',
                          onPressed: onReject,
                        ),
                      ),
                    ] else ...[
                      // Remove Button for approved members
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red,
                          tooltip: 'Remove',
                          onPressed: onRemove,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}