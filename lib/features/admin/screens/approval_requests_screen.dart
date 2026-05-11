import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/members/screens/member_profile_screen.dart';
import 'package:kofund/core/skeleton/approval_requests_skeleton.dart';
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
    final _authProvider = context.read<AppAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final communityId = _authProvider.user?.communityId;
    
    _currentUser = _authProvider.user; // Store current user

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

  Widget _buildGlassSearchBar() {
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
          child: Row(
            children: [
              // Search Icon Container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
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
                    hintText: 'Search members...',
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
                            child: SizedBox(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: AppColors.textSecondary(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
              cursorColor: AppColors.primary(context),
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                isDense: true,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 20, color: AppColors.textSecondary(context)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
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
    final _authProvider = context.read<AppAuthProvider>();
    final communityId = _authProvider.user?.communityId;
    
    // Get current user for comparison
    _currentUser = _authProvider.user;

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

    return GradientSheetScaffold(
      title: 'Community Members',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
            child: _buildSheetSearchBar(),
          ),
          Expanded(
            child: SmartRefresher(
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
        child: userProvider.isLoading && userProvider.pendingMembers.isEmpty && userProvider.approvedMembers.isEmpty
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [ApprovalRequestsSkeleton.buildList(context)],
            )
          : CustomScrollView(
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
                            final currentAdminName = Provider.of<AppAuthProvider>(context, listen: false).user?.displayName;
                            await userProvider.approveUser(user.uid, communityId, adminName: currentAdminName);
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
          ),
        ],
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

  Widget _buildDismissibleBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ] else ...[
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 24),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String contactInfo =
        user.phoneNumber?.isNotEmpty == true
            ? user.phoneNumber!
            : user.email.isNotEmpty == true
                ? user.email
                : 'No contact info';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to MemberProfileScreen when user is clicked
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemberProfileScreen(member: user),
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
                          _getInitials(user.displayName ?? user.email),
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
                                  user.displayName ?? 'Unnnamed Member',
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isApproved) ...[
                        // Approve Button
                        ElevatedButton(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            minimumSize: const Size(0, 32),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                          ),
                          child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        // Reject Icon
                        IconButton(
                          onPressed: onReject,
                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFF43F5E), size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Reject',
                        ),
                      ] else
                        _PillButton(
                          label: 'Remove',
                          icon: Icons.close_rounded,
                          color: AppColors.textSecondary(context),
                          onTap: onRemove,
                        ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'You',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





