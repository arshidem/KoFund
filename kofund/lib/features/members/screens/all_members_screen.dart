// lib/features/members/screens/all_members_screen.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kofund/core/constants/app_colors.dart';
import '../providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'member_details_screen.dart';
import 'package:kofund/core/skeleton/member_list_skeleton.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:badges/badges.dart' as badges;
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/virtual_users/screens/create_virtual_users_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/dialog_helper.dart';

enum MemberTypeFilter { all, real, virtual }

// =================== MAIN SCREEN ===================
class AllMembersScreen extends StatelessWidget {
  final bool? forceBackButton;

  const AllMembersScreen({super.key, this.forceBackButton});

  @override
  Widget build(BuildContext context) {
    // ⭐ Use the global MemberProvider from main.dart instead of creating
    // a new one every time. This preserves cached data across navigations.
    return _AllMembersScreenBody(forceBackButton: forceBackButton);
  }
}

// =================== SCREEN BODY ===================
class _AllMembersScreenBody extends StatefulWidget {
  final bool? forceBackButton;

  const _AllMembersScreenBody({this.forceBackButton});

  @override
  State<_AllMembersScreenBody> createState() => _AllMembersScreenBodyState();
}

// =================== SCREEN STATE ===================
class _AllMembersScreenBodyState extends State<_AllMembersScreenBody>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  String _searchQuery = '';
  int _selectedTab = 0; // 0 = All Members, 1 = Pending Approvals
  bool _isSelectionMode = false;
  final Set<String> _selectedMemberIds = {};
  MemberTypeFilter _memberTypeFilter = MemberTypeFilter.all;

  // Load tracking
  bool _isInitialLoad = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Track current user ID to detect user changes
  String? _currentUserId;

  late AnimationController _tabAnimationController;
  late Animation<double> _tabIndicatorAnimation;

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: AllMembersScreen initState called');

    _tabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tabIndicatorAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tabAnimationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadMembers();
    });
  }

  void _onTabTap(int index) {
    if (_selectedTab != index) {
      setState(() => _selectedTab = index);
      if (index == 1) {
        _tabAnimationController.forward();
        _loadPendingMembersSilent();
      } else {
        _tabAnimationController.reverse();
        _loadMembersSilent();
      }
    }
  }

  Future<void> _loadMembersSilent() async {
    final memberProvider = context.read<MemberProvider>();
    try {
      await memberProvider.loadMembers();
    } catch (e) {
      print('❌ DEBUG: Silent load members failed: $e');
    }
  }

  Future<void> _loadPendingMembersSilent() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = context.read<AppAuthProvider>().user;
    if (currentUser?.communityId != null) {
      try {
        await userProvider.loadCommunityMembers(currentUser!.communityId!);
      } catch (e) {
        print('❌ DEBUG: Silent load pending failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    _tabAnimationController.dispose();
    super.dispose();
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

      // Load members for new user
      if (mounted) {
        _checkAuthAndLoadMembers();
      }
    }

    if (user != null && _isInitialLoad && _currentUserId == null) {
      print('👤 DEBUG: First load for user ${user.uid}');
      _currentUserId = user.uid;
      _checkAuthAndLoadMembers();
    }
  }

  void _resetScreenForNewUser() {
    if (!mounted) return;

    print('🔄 DEBUG: Resetting screen for new user');

    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSelectionMode = false;
      _selectedMemberIds.clear();
      _isInitialLoad = true;
      _isLoading = false;
      _errorMessage = null;
    });

    // Reset the provider as well
    final memberProvider = context.read<MemberProvider>();
    memberProvider.resetForNewUser();
  }

  void _checkAuthAndLoadMembers() {
    if (!mounted) return;

    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;

    print(
      '🔍 DEBUG: Checking auth state - UID: ${user?.uid}, Community: ${user?.communityId}, Approved: ${user?.isApproved}',
    );

    if (user == null) {
      print('❌ DEBUG: No user found, waiting for authentication...');
      setState(() {
        _isInitialLoad = false;
        _isLoading = false;
        _errorMessage = 'Please sign in to view members';
      });
      return;
    }

    if (user.communityId == null) {
      print('❌ DEBUG: No communityId found for user');
      setState(() {
        _isInitialLoad = false;
        _isLoading = false;
        _errorMessage = 'You are not part of any community';
      });
      return;
    }

    print('✅ DEBUG: User and community found, loading members...');
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;

    print('🔄 DEBUG: Loading members...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final memberProvider = context.read<MemberProvider>();
      final userProvider = context.read<UserProvider>();
      final currentUser = context.read<AppAuthProvider>().user;
      
      // Load both in parallel for efficiency
      final List<Future> futures = [memberProvider.loadMembers()];
      
      if (currentUser?.isAdmin == true && currentUser?.communityId != null) {
        futures.add(userProvider.loadCommunityMembers(currentUser!.communityId!));
      }
      
      await Future.wait(futures);

      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoading = false;
          _errorMessage = 'Failed to load members: $error';
        });
        print('❌ DEBUG: Error loading members: $error');
      }
    }
  }

  // Pull to refresh handler
  void _onRefresh() async {
    HapticHelper.light();
    print('🔄 DEBUG: Pull to refresh triggered for tab $_selectedTab');

    try {
      if (_selectedTab == 0) {
        final memberProvider = context.read<MemberProvider>();
        await memberProvider.loadMembers(reset: true);
      } else {
        final userProvider = context.read<UserProvider>();
        final currentUser = context.read<AppAuthProvider>().user;
        if (currentUser?.communityId != null) {
          await userProvider.loadCommunityMembers(currentUser!.communityId!);
        }
      }

      _refreshController.refreshCompleted();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('✅ DEBUG: Refresh completed successfully');
    } catch (e) {
      _refreshController.refreshFailed();
      print('❌ DEBUG: Refresh failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // ✅ SELECTION MODE METHODS
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMemberIds.clear();
      }
    });
  }

  void _toggleMemberSelection(String memberId) {
    final currentUser = context.read<AppAuthProvider>().user;
    if (memberId == currentUser?.uid) return;

    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
      }

      if (_selectedMemberIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAllMembers(List<UserModel> members) {
    final currentUser = context.read<AppAuthProvider>().user;
    final selectableMembers = members
        .where((m) => m.uid != currentUser?.uid)
        .toList();

    setState(() {
      if (_selectedMemberIds.length == selectableMembers.length &&
          selectableMembers.isNotEmpty) {
        _selectedMemberIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedMemberIds.clear();
        _selectedMemberIds.addAll(selectableMembers.map((m) => m.uid));
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMemberIds.clear();
      _isSelectionMode = false;
    });
  }

  // ✅ BULK ACTION METHODS - FIXED: Added back the missing methods
  void _showBulkActionsMenu(BuildContext context) {
    final memberProvider = context.read<MemberProvider>();

    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select members first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentMembers = List<UserModel>.from(memberProvider.members);
    final currentSelectedIds = Set<String>.from(_selectedMemberIds);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusExtraLarge)),
      ),
      builder: (context) => _buildBulkActionsBottomSheet(
        members: currentMembers,
        selectedIds: currentSelectedIds,
      ),
      useRootNavigator: true,
    );
  }

  Widget _buildBulkActionsBottomSheet({
    required List<UserModel> members,
    required Set<String> selectedIds,
  }) {
    final selectedMembers = members
        .where((m) => selectedIds.contains(m.uid))
        .toList();

    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final card = AppColors.card(context);
    final primary = AppColors.primary(context);

    /// --------------------
    /// EMPTY STATE
    /// --------------------
    if (selectedMembers.isEmpty) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: primary),
              const SizedBox(height: 12),
              Text(
                'No members selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: textSecondary)),
              ),
            ],
          ),
        ),
      );
    }

    final hasAdmins = selectedMembers.any((m) => m.isAdmin);
    final hasNonAdmins = selectedMembers.any((m) => !m.isAdmin);

    /// --------------------
    /// MAIN BOTTOM SHEET
    /// --------------------
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    "Bulk Actions",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${selectedMembers.length} selected",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            /// ACTION LIST
            _actionTile(
              icon: Icons.admin_panel_settings,
              iconColor: primary,
              title: "Make Admin",
              subtitle:
                  "Make ${selectedMembers.where((m) => !m.isAdmin).length} user(s) admin",
              visible: hasNonAdmins,
              onTap: () {
                Navigator.pop(context);
                _showBulkMakeAdminConfirmation(selectedMembers);
              },
            ),

            _actionTile(
              icon: Icons.person_remove_alt_1,
              iconColor: AppColors.warning(context),
              title: "Remove Admin",
              subtitle:
                  "Remove admin role from ${selectedMembers.where((m) => m.isAdmin).length} user(s)",
              visible: hasAdmins,
              onTap: () {
                Navigator.pop(context);
                _showBulkRemoveAdminConfirmation(selectedMembers);
              },
            ),

            _actionTile(
              icon: Icons.block,
              iconColor: AppColors.error(context),
              title: "Unapprove Users",
              subtitle: "Unapprove ${selectedMembers.length} user(s)",
              onTap: () {
                Navigator.pop(context);
                _showBulkUnapproveConfirmation(selectedMembers);
              },
            ),

            _actionTile(
              icon: Icons.exit_to_app,
              iconColor: Colors.purple,
              title: "Remove from Community",
              subtitle: "Remove ${selectedMembers.length} user(s)",
              onTap: () {
                Navigator.pop(context);
                _showBulkRemoveConfirmation(selectedMembers);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------
  /// REUSABLE ACTION TILE
  /// ---------------------------------------------
  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool visible = true,
  }) {
    if (!visible) return const SizedBox();
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 72),
          child: Divider(height: 1, color: AppColors.border(context)),
        ),
      ],
    );
  }

  void _showBulkMakeAdminConfirmation(List<UserModel> members) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Make Users Admin?',
      message: 'Are you sure you want to make ${members.length} user${members.length > 1 ? 's' : ''} admin? This will grant them administrative privileges.',
      confirmLabel: 'Make Admin',
      icon: Icons.admin_panel_settings_rounded,
    );

    if (result == true) {
      _bulkMakeAdmin(members);
    }
  }

  void _showBulkRemoveAdminConfirmation(List<UserModel> members) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Remove Admin Role?',
      message: 'Are you sure you want to remove admin role from ${members.length} user${members.length > 1 ? 's' : ''}?',
      confirmLabel: 'Remove Admin',
      icon: Icons.person_remove_alt_1_rounded,
      isDestructive: true,
    );

    if (result == true) {
      _bulkRemoveAdmin(members);
    }
  }

  void _showBulkUnapproveConfirmation(List<UserModel> members) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Unapprove Users?',
      message: 'Are you sure you want to unapprove ${members.length} user${members.length > 1 ? 's' : ''}? They will lose access to member-only areas.',
      confirmLabel: 'Unapprove',
      icon: Icons.block_flipped,
      isDestructive: true,
    );

    if (result == true) {
      _bulkUnapproveUsers(members);
    }
  }

  void _showBulkRemoveConfirmation(List<UserModel> members) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Remove from Community?',
      message: 'Are you sure you want to remove ${members.length} user${members.length > 1 ? 's' : ''} from the community? This action is permanent.',
      confirmLabel: 'Remove',
      icon: Icons.person_remove_rounded,
      isDestructive: true,
    );

    if (result == true) {
      _bulkRemoveFromCommunity(members);
    }
  }

  // ✅ BULK ACTION IMPLEMENTATIONS
  void _bulkMakeAdmin(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();

    final success = await memberProvider.bulkUpdateMemberRoles(uids, true);

    if (success && mounted) {
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Made ${members.length} users admin'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshDataSilent();
    }
  }

  void _bulkRemoveAdmin(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();

    final success = await memberProvider.bulkUpdateMemberRoles(uids, false);

    if (success && mounted) {
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed admin role from ${members.length} users'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshDataSilent();
    }
  }

  void _bulkUnapproveUsers(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();

    final success = await memberProvider.bulkUnapproveUsers(uids);

    if (success && mounted) {
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unapproved ${members.length} users'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshDataSilent();
    }
  }

  void _bulkRemoveFromCommunity(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();

    final success = await memberProvider.bulkRemoveFromCommunity(uids);

    if (success && mounted) {
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${members.length} users from community'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshDataSilent();
    }
  }

  // ✅ NAVIGATION METHOD
  void _navigateToMemberDetails(UserModel member) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberDetailsScreen(member: member)),
    );

    if (mounted) {
      _refreshDataSilent();
    }
  }

  Future<void> _refreshDataSilent() async {
    final memberProvider = context.read<MemberProvider>();
    final userProvider = context.read<UserProvider>();
    final currentUser = context.read<AppAuthProvider>().user;

    final List<Future> futures = [memberProvider.loadMembers()];

    if (currentUser?.isAdmin == true && currentUser?.communityId != null) {
      futures.add(userProvider.loadCommunityMembers(currentUser!.communityId!));
    }

    try {
      await Future.wait(futures);
    } catch (e) {
      print('❌ DEBUG: Silent data refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberProvider = context.watch<MemberProvider>();
    final isAdmin = context.read<AppAuthProvider>().user?.isAdmin == true;
    final currentUser = context.read<AppAuthProvider>().user;

    // Apply search
    List<UserModel> displayedMembers = _searchQuery.isEmpty
        ? memberProvider.members
        : memberProvider.searchMembers(_searchQuery);

    // Apply type filter
    if (_memberTypeFilter == MemberTypeFilter.real) {
      displayedMembers = displayedMembers
          .where((m) => m.isVirtualUser != true)
          .toList();
    } else if (_memberTypeFilter == MemberTypeFilter.virtual) {
      displayedMembers = displayedMembers
          .where((m) => m.isVirtualUser == true)
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [_buildSliverAppBar(context, isAdmin, displayedMembers)];
        },
        body: _buildMembersView(isAdmin, currentUser, displayedMembers),
      ),
      floatingActionButton: (isAdmin && _selectedTab == 0 && !_isSelectionMode)
          ? _buildVirtualUserFAB()
          : null,
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    bool isAdmin,
    List<UserModel> displayedMembers,
  ) {
    // Search row: 52, Padding bottom: 12 => 64 base height
    // If admin, add gap (15) and filter bar (52) => 67 extra height
    // Plus bottom rounded container: 24
    final double bottomContentHeight = isAdmin ? (64.0 + 67.0) : 64.0;
    final double totalBottomHeight = bottomContentHeight + 24.0;

    // Dynamic collapsed/expanded calculation
    const double toolbarHeight = 64.0;
    final double collapsedHeight = toolbarHeight + totalBottomHeight;
    final double expandedHeight = collapsedHeight + 36.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      toolbarHeight: toolbarHeight,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent, // Let flexibleSpace handle color
      automaticallyImplyLeading: false,
      leading: widget.forceBackButton == true
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      // Dynamic Title using flexibleSpace for scaling effect
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          final double currentHeight = top;

          final double progress =
              ((currentHeight - collapsedHeight) /
                      (expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);

          // Font size: 20 at expanded, 18 at collapsed
          final double fontSize = 18 + (2 * progress);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 🔋 PERSISTENT GRADIENT BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient(context),
                ),
              ),

              FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                centerTitle: true,
                titlePadding: EdgeInsets.only(bottom: totalBottomHeight + 10),
                title: Text(
                  'Members',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5 - (0.5 * progress),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(totalBottomHeight),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingHorizontal,
                0,
                AppDimensions.screenPaddingHorizontal,
                12,
              ),
              child: Column(
                children: [
                  _buildModernSearchBar(),
                  if (isAdmin) ...[
                    const SizedBox(height: 15),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _isSelectionMode
                          ? _buildSelectionControls(displayedMembers, isAdmin)
                          : _buildSegmentedFilterBar(),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.radiusExtraLarge),
                  topRight: Radius.circular(AppDimensions.radiusExtraLarge),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedFilterBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          // Sliding Indicator
          AnimatedBuilder(
            animation: _tabIndicatorAnimation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth / 2;
                  return Transform.translate(
                    offset: Offset(_tabIndicatorAnimation.value * width, 0),
                    child: Container(
                      width: width,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Tab Items
          Row(
            children: [
              _buildFilterTabItem('ALL MEMBERS', 0),
              _buildFilterTabItem('PENDING', 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabItem(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTap(index),
        child: Container(
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? AppColors.primary(context)
                  : Colors.white.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersView(
    bool isAdmin,
    UserModel? currentUser,
    List<UserModel> displayedMembers,
  ) {
    return Container(
      width: double.infinity,
      color: AppColors.card(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () async => _onRefresh()),
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: _buildMembersListWithFade(isAdmin, currentUser, displayedMembers),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildMembersListWithFade(
    bool isAdmin,
    UserModel? currentUser,
    List<UserModel> displayedMembers,
  ) {
    if (_selectedTab == 1) {
      // Pending Approvals View
      final userProvider = context.watch<UserProvider>();
      List<UserModel> pendingMembers = userProvider.pendingMembers;

      // ✅ APPLY SEARCH TO PENDING MEMBERS
      if (_searchQuery.isNotEmpty) {
        pendingMembers = pendingMembers.where((m) {
          final query = _searchQuery.toLowerCase();
          return (m.displayName?.toLowerCase().contains(query) ?? false) ||
                 (m.email.toLowerCase().contains(query) ?? false) ||
                 (m.phoneNumber?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      // ✅ APPLY FILTERS TO PENDING MEMBERS
      if (_memberTypeFilter == MemberTypeFilter.real) {
        pendingMembers = pendingMembers
            .where((m) => m.isVirtualUser != true)
            .toList();
      } else if (_memberTypeFilter == MemberTypeFilter.virtual) {
        pendingMembers = pendingMembers
            .where((m) => m.isVirtualUser == true)
            .toList();
      }

      if (userProvider.isLoading && pendingMembers.isEmpty) {
        return MemberListSkeleton.buildSliver(
          context,
          Theme.of(context).brightness == Brightness.dark,
        );
      }

      if (pendingMembers.isEmpty) {
        return SliverToBoxAdapter(child: _buildEmptyStatePending());
      }

      return SliverList.separated(
        key: const ValueKey('pending_list'),
        itemCount: pendingMembers.length + (_searchQuery.isNotEmpty ? 1 : 0),
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 0,
          endIndent: 0,
          color: AppColors.textSecondary(context).withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          if (_searchQuery.isNotEmpty && index == 0) {
            return _buildSearchHeader(pendingMembers.length);
          }
          final member =
              pendingMembers[index - (_searchQuery.isNotEmpty ? 1 : 0)];
          return _buildMemberTile(member, currentUser);
        },
      );
    } else {
      // All Members View
      final memberProvider = context.watch<MemberProvider>();

      if (_isInitialLoad ||
          (memberProvider.isLoading && displayedMembers.isEmpty) ||
          (_isLoading && displayedMembers.isEmpty)) {
        return MemberListSkeleton.buildSliver(
          context,
          Theme.of(context).brightness == Brightness.dark,
        );
      }

      if (displayedMembers.isEmpty) {
        return SliverToBoxAdapter(child: _buildEmptyState());
      }

      return SliverList.separated(
        key: const ValueKey('all_members_list'),
        itemCount: displayedMembers.length + (_searchQuery.isNotEmpty ? 1 : 0),
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 0,
          endIndent: 0,
          color: AppColors.textSecondary(context).withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          if (_searchQuery.isNotEmpty && index == 0) {
            return _buildSearchHeader(displayedMembers.length);
          }
          final member =
              displayedMembers[index - (_searchQuery.isNotEmpty ? 1 : 0)];
          return _buildMemberTile(member, currentUser);
        },
      );
    }
  }

  Widget _buildEmptyStatePending() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: AppColors.textSecondary(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending requests',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Search members...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white70,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => _openFilterSheet(context),
              child: Center(
                child: badges.Badge(
                  showBadge: false, // track count if needed
                  child: const Icon(Icons.tune, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ SEARCH HEADER
  Widget _buildSearchHeader(int resultCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.04),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: AppColors.primary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search results for "$_searchQuery"',
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

  // ✅ SELECTION CONTROLS WIDGET
  Widget _buildSelectionControls(
    List<UserModel> displayedMembers,
    bool isAdmin,
  ) {
    final currentUser = context.read<AppAuthProvider>().user;
    final selectableCount = displayedMembers
        .where((m) => m.uid != currentUser?.uid)
        .length;

    return RepaintBoundary(
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Cancel Button
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: AppColors.primary(context),
                  size: 22,
                ),
                onPressed: _toggleSelectionMode,
                tooltip: 'Cancel selection',
              ),

              // Selection Count
              Expanded(
                child: Text(
                  '${_selectedMemberIds.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.primary(context),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Select All / Deselect All
              IconButton(
                icon: Icon(
                  (_selectedMemberIds.length == selectableCount &&
                          selectableCount > 0)
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: AppColors.primary(context),
                  size: 22,
                ),
                onPressed:
                    (_selectedMemberIds.length == selectableCount &&
                        selectableCount > 0)
                    ? _clearSelection
                    : () => _selectAllMembers(displayedMembers),
                tooltip:
                    (_selectedMemberIds.length == selectableCount &&
                        selectableCount > 0)
                    ? 'Deselect all'
                    : 'Select all',
              ),

              // Actions Menu
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.primary(context),
                  size: 22,
                ),
                onPressed: _selectedMemberIds.isNotEmpty
                    ? () => _showBulkActionsMenu(context)
                    : null,
                tooltip: 'Bulk actions',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        if (_searchQuery.isNotEmpty)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: 1.0,
            child: Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.primary(context).withValues(alpha: 0.5),
            ),
          )
        else
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.primary(context).withValues(alpha: 0.5),
          ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _searchQuery.isNotEmpty
                ? 'No results found'
                : 'No members available',
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
            _searchQuery.isNotEmpty
                ? 'No matches for "$_searchQuery"'
                : 'When members join and get approved,\nthey will appear here.',
            style: TextStyle(color: AppColors.textSecondary(context)),
            textAlign: TextAlign.center,
          ),
        ),
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
              ),
              child: const Text('Clear Search'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMemberTile(UserModel member, UserModel? currentUser) {
    final isSelected = _selectedMemberIds.contains(member.uid);
    final isAdmin = currentUser?.isAdmin == true;
    final isCurrentUser = member.uid == currentUser?.uid;

    return Material(
      color: isSelected
          ? AppColors.primary(context).withValues(alpha: 0.12)
          : AppColors.card(context),
      child: InkWell(
        onTap: () {
          if (_selectedTab == 1) {
            // No selection or navigation for pending in this view?
            // Or maybe still allow navigation to details?
            _navigateToMemberDetails(member);
          } else if (_isSelectionMode && isAdmin) {
            if (!isCurrentUser) {
              setState(() {
                _toggleMemberSelection(member.uid);
              });
            }
          } else {
            _navigateToMemberDetails(member);
          }
        },
        onLongPress: (isAdmin && !isCurrentUser && _selectedTab == 0)
            ? () {
                setState(() {
                  if (!_isSelectionMode) {
                    _isSelectionMode = true;
                  }
                  _toggleMemberSelection(member.uid);
                });
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary(
                      context,
                    ).withValues(alpha: 0.12),
                    child: Text(
                      (member.displayName?.isNotEmpty == true
                          ? member.displayName![0].toUpperCase()
                          : '?'),
                      style: TextStyle(
                        color: AppColors.primary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_isSelectionMode && _selectedTab == 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary(context)
                              : Colors.grey[400],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.card(context),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.circle_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName ?? 'No Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.email ?? 'No email',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(
                          context,
                        ).withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Action Buttons for Pending Members
              if (_selectedTab == 1 && isAdmin && !isCurrentUser) ...[
                const SizedBox(width: 8),
                // Approve Button
                ElevatedButton(
                  onPressed: () async {
                    if (currentUser?.communityId != null) {
                      final userProvider = context.read<UserProvider>();
                      await userProvider.approveUser(
                        member.uid,
                        currentUser!.communityId!,
                      );
                      if (mounted) {
                        SnackbarHelper.showSuccess(context, 'User approved');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                // Reject Icon
                IconButton(
                  onPressed: () async {
                    final confirmed = await _showRejectConfirmation(
                      context,
                      member,
                    );
                    if (confirmed == true && mounted) {
                      final userProvider = context.read<UserProvider>();
                      await userProvider.rejectUser(member.uid);
                      if (mounted) {
                        SnackbarHelper.showInfo(context, 'User rejected');
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFFF43F5E),
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Reject',
                ),
              ] else if (member.phoneNumber != null &&
                  member.phoneNumber!.isNotEmpty)
                IconButton(
                  onPressed: () => _makePhoneCall(member.phoneNumber),
                  icon: Icon(
                    Icons.call_rounded,
                    color: AppColors.primary(context),
                    size: 20,
                  ),
                  tooltip: 'Call member',
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary(
                    context,
                  ).withValues(alpha: 0.3),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualUserFAB() {
    final currentUser = context.read<AppAuthProvider>().user;
    return FloatingActionButton(
      onPressed: () {
        if (currentUser?.communityId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateVirtualUsersScreen(
                communityId: currentUser!.communityId!,
                communityName: currentUser.communityName ?? 'Community',
              ),
            ),
          ).then((value) {
            if (value != null && value > 0) {
              _onRefresh();
            }
          });
        }
      },
      backgroundColor: const Color(0xFF00BFA5),
      elevation: 4,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusExtraLarge)),
      ),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Filter Members',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Filter chips for member type
              StatefulBuilder(
                builder: (context, setModalState) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All Members',
                        isActive: _memberTypeFilter == MemberTypeFilter.all,
                        onTap: () {
                          setState(
                            () => _memberTypeFilter = MemberTypeFilter.all,
                          );
                          setModalState(() {});
                        },
                      ),
                      _buildFilterChip(
                        label: 'Real Users',
                        isActive: _memberTypeFilter == MemberTypeFilter.real,
                        onTap: () {
                          setState(
                            () => _memberTypeFilter = MemberTypeFilter.real,
                          );
                          setModalState(() {});
                        },
                      ),
                      _buildFilterChip(
                        label: 'Virtual Users',
                        isActive: _memberTypeFilter == MemberTypeFilter.virtual,
                        onTap: () {
                          setState(
                            () => _memberTypeFilter = MemberTypeFilter.virtual,
                          );
                          setModalState(() {});
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary(context) : Colors.transparent,
          border: Border.all(
            color: isActive
                ? AppColors.primary(context)
                : AppColors.textSecondary(context).withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary(context),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  // ✅ ADD REJECT CONFIRMATION
  Future<bool?> _showRejectConfirmation(
    BuildContext context,
    UserModel user,
  ) async {
    return await DialogHelper.showConfirmationDialog(
      context,
      title: 'Reject User?',
      message: 'Are you sure you want to reject ${user.displayName ?? "this user"}? This action cannot be undone.',
      confirmLabel: 'Reject',
      isDestructive: true,
    );
  }
}
