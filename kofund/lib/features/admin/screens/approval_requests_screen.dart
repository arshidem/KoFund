import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/members/screens/member_details_screen.dart';
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
  UserModel? _currentUser;

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
    
    _currentUser = authProvider.user; // Store current user

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

  // Helper method to check if user is current user
  bool _isCurrentUser(UserModel user) {
    return _currentUser?.uid == user.uid;
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
    return Container(
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
              contentPadding: const EdgeInsets.fromLTRB(10, 18, 6, 2),
              hintText: 'Search members...',
              hintStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              filled: false,
              prefixIcon: Container(
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
                            setState(() => _searchQuery = '');
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(int resultCount, String section) {
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
              color: AppColors.primary(context).withValues(alpha: 0.18),
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
    
    // Get current user for comparison
    _currentUser = authProvider.user;

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
        title: const Text(
          'Community Members',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                        color: AppColors.primary(context).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No pending members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context).withValues(alpha: 0.7),
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
                    return Column(
                      children: [
                        _MemberCard(
                          user: user,
                          provider: userProvider,
                          communityId: communityId,
                          isApproved: false,
                          isCurrentUser: _isCurrentUser(user),
                          onApprove: () async {
                            await userProvider.approveUser(user.uid, communityId);
                            if (!mounted) return;
                            SnackbarHelper.showSuccess(context, 'User approved');
                            await userProvider.loadCommunityMembers(communityId);
                          },
                          onReject: () async {
                            final confirmed = await _showRejectConfirmation(context, user);
                            if (!mounted) return;
                            if (confirmed == true) {
                              await userProvider.rejectUser(user.uid);
                              if (!mounted) return;
                              SnackbarHelper.showInfo(context, 'User rejected');
                              await userProvider.loadCommunityMembers(communityId);
                            }
                          },
                        ),
                        if (index < filteredPending.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.8,
                            color: AppColors.border(context),
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
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
                        color: AppColors.primary(context).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No approved members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context).withValues(alpha: 0.7),
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
                    return Column(
                      children: [
                        _MemberCard(
                          user: user,
                          provider: userProvider,
                          communityId: communityId,
                          isApproved: true,
                          isCurrentUser: _isCurrentUser(user),
                          onRemove: () async {
                            final confirmed = await _showRemoveConfirmation(context, user);
                            if (!mounted) return;
                            if (confirmed == true) {
                              await userProvider.unapproveUser(user.uid);
                              if (!mounted) return;
                              SnackbarHelper.showInfo(context, 'User removed');
                              await userProvider.loadCommunityMembers(communityId);
                            }
                          },
                        ),
                        if (index < filteredApproved.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.8,
                            color: AppColors.border(context),
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
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
  final bool isCurrentUser;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.user,
    required this.provider,
    required this.communityId,
    required this.isApproved,
    required this.isCurrentUser,
    this.onApprove,
    this.onReject,
    this.onRemove,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final String contactInfo =
        user.phoneNumber?.isNotEmpty == true
            ? user.phoneNumber!
            : user.email?.isNotEmpty == true
                ? user.email!
                : 'No contact info';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to MemberDetailsScreen when user is clicked
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemberDetailsScreen(member: user),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Square avatar container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isApproved 
                      ? AppColors.primary(context).withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Stack(
                    children: [
                      Text(
                        _getInitials(user.displayName ?? user.email ?? '?'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isApproved 
                              ? AppColors.primary(context)
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Name + contact
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                user.displayName ?? 'Unnamed Member',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              if (isCurrentUser)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.blue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contactInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

        

              // Action Buttons - DISABLED for current user
              if (!isCurrentUser)
                Wrap(
                  spacing: 4,
                  children: [
                    if (!isApproved) ...[
                      // Approve Button (green check)
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        color: Colors.green,
                        tooltip: 'Approve',
                        onPressed: onApprove,
                      ),
                      // Reject Button (red X)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.red,
                        tooltip: 'Reject',
                        onPressed: onReject,
                      ),
                    ] else ...[
                      // Remove Button for approved members (red X instead of delete)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.red,
                        tooltip: 'Remove',
                        onPressed: onRemove,
                      ),
                    ],
                  ],
                )
              else
                // Show disabled state for current user
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.border(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
