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
import 'member_profile_screen.dart';
import 'package:kofund/core/skeleton/member_list_skeleton.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:badges/badges.dart' as badges;
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/virtual_users/screens/create_virtual_users_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/dialog_helper.dart';

enum MemberTeventTypeFilter { all, real, virtual }

// =================== MAIN SCREEN ===================
class AllMembersScreen extends StatelessWidget {
  final bool? forceBackButton;
  final VoidCallback? onBack;

  const AllMembersScreen({super.key, this.forceBackButton, this.onBack});

  @override
  Widget build(BuildContext context) {
    return _AllMembersScreenBody(
      forceBackButton: forceBackButton,
      onBack: onBack,
    );
  }
}

// =================== SCREEN BODY ===================
class _AllMembersScreenBody extends StatefulWidget {
  final bool? forceBackButton;
  final VoidCallback? onBack;

  const _AllMembersScreenBody({this.forceBackButton, this.onBack});

  @override
  State<_AllMembersScreenBody> createState() => _AllMembersScreenBodyState();
}

// =================== SCREEN STATE ===================
class _AllMembersScreenBodyState extends State<_AllMembersScreenBody>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  String _searchQuery = '';
  int _selectedTab = 0; // 0 = All Members, 1 = Pending Approvals
  bool _isSelectionMode = false;
  final Set<String> _selectedMemberIds = {};
  MemberTeventTypeFilter _memberTeventTypeFilter = MemberTeventTypeFilter.all;

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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🔄 DEBUG: didChangeDependencies called');

    final _authProvider = context.read<AppAuthProvider>();
    final user = _authProvider.user;

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

    final _authProvider = context.read<AppAuthProvider>();
    final user = _authProvider.user;

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

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
      SnackbarHelper.showSuccess(context, 'Made ${members.length} users admin');
      _refreshDataSilent();
    }
  }

  void _bulkRemoveAdmin(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();

    final success = await memberProvider.bulkUpdateMemberRoles(uids, false);

    if (success && mounted) {
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Removed admin role from ${members.length} users');
      _refreshDataSilent();
    }
  }

  void _bulkUnapproveUsers(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();

    final success = await memberProvider.bulkUnapproveUsers(uids);

    if (success && mounted) {
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Unapproved ${members.length} users');
      _refreshDataSilent();
    }
  }

  void _bulkRemoveFromCommunity(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();

    final success = await memberProvider.bulkRemoveFromCommunity(uids);

    if (success && mounted) {
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Removed ${members.length} users from community');
      _refreshDataSilent();
    }
  }

  // ✅ NAVIGATION METHOD
  void _navigateToMemberDetails(UserModel member) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberProfileScreen(member: member)),
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
    if (_memberTeventTypeFilter == MemberTeventTypeFilter.real) {
      displayedMembers = displayedMembers
          .where((m) => m.isVirtualUser != true)
          .toList();
    } else if (_memberTeventTypeFilter == MemberTeventTypeFilter.virtual) {
      displayedMembers = displayedMembers
          .where((m) => m.isVirtualUser == true)
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        controller: _scrollController,
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
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double expandedHeightConfig = isAdmin ? 220.0 : 160.0;
    final double collapsedHeightConfig = 72.0 + 24.0 + (isAdmin ? 52.0 : 0.0); 

    return SliverAppBar(
      expandedHeight: expandedHeightConfig,
      toolbarHeight: collapsedHeightConfig,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: AppColors.background(context),
      automaticallyImplyLeading: false,
      leading: widget.forceBackButton == true
          ? Transform.translate(
              offset: const Offset(0, -40),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            )
          : null,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          final double expandedHeight = expandedHeightConfig + statusBarHeight;
          final double collapsedHeight = collapsedHeightConfig + statusBarHeight;
          
          final double rawProgress = (top - collapsedHeight) / (expandedHeight - collapsedHeight);
          final double progress = rawProgress.clamp(0.0, 1.0);
          
          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          
          final double titleTop = statusBarHeight + 16 + (4 * progress);
          final double titleFontSize = 24 + (4 * progress);
          
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: isDark 
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1A2E2E),
                            Color(0xFF0D1B1A),
                          ],
                        )
                      : null,
                ),
              ),
              
              
              Positioned(
                top: titleTop,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Members',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        color: isDark 
                            ? Colors.white 
                            : AppColors.textPrimary(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
              
              Positioned(
                top: statusBarHeight + 10,
                right: 24.0,
                child: Opacity(
                  opacity: (0.5 - progress).clamp(0.0, 0.5) * 2.0,
                  child: IgnorePointer(
                    ignoring: progress > 0.5,
                    child: _buildCollapsedActionIcons(context),
                  ),
                ),
              ),
              
              Positioned(
                bottom: 30.0, 
                left: 24.0,
                right: 24.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: (progress - 0.5).clamp(0.0, 0.5) * 2.0,
                      child: IgnorePointer(
                        ignoring: progress < 0.5,
                        child: _buildExpandedSearchRow(context, displayedMembers, isAdmin),
                      ),
                    ),
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
              
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCollapsedActionIcons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircularIconButton(
          context, 
          icon: Icons.search, 
          onTap: () {
            _scrollController.animateTo(
              0.0, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeOut,
            );
          }
        ),
        const SizedBox(width: 8),
        _buildFilterIconButton(context, collapsed: true),
      ],
    );
  }

  Widget _buildCircularIconButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.textSecondary(context),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterIconButton(BuildContext context, {bool collapsed = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int filterCount = _memberTeventTypeFilter != MemberTeventTypeFilter.all ? 1 : 0;
    
    return Container(
      width: collapsed ? 44 : 52,
      height: collapsed ? 44 : 52,
      decoration: collapsed
          ? null
          : BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.card(context).withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context),
                width: 1,
              ),
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _openFilterSheet(context),
          child: Center(
            child: badges.Badge(
              showBadge: filterCount > 0,
              badgeContent: Text(
                filterCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              badgeStyle: badges.BadgeStyle(
                badgeColor: AppColors.error(context),
                padding: const EdgeInsets.all(4),
                elevation: 0,
              ),
              position: badges.BadgePosition.topEnd(top: -6, end: -6),
              child: Icon(
                Icons.tune,
                color: collapsed 
                    ? AppColors.textSecondary(context) 
                    : (isDark ? Colors.white : Colors.black),
                size: collapsed ? 24 : 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedSearchRow(BuildContext context, List<UserModel> displayedMembers, bool isAdmin) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color searchBg = isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.card(context).withValues(alpha: 0.8);
    final Color searchBorder = isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context);
    final Color textColor = isDark ? Colors.white : AppColors.textPrimary(context);
    final Color iconColorVal = isDark ? Colors.white70 : Colors.black;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: searchBorder),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
                letterSpacing: 0.3,
              ),
              cursorColor: textColor,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Search members...',
                filled: false,
                hintStyle: TextStyle(
                  color: iconColorVal,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: iconColorVal,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: iconColorVal,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
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
        _buildFilterIconButton(context, collapsed: false),
      ],
    );
  }

  Widget _buildSegmentedFilterBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.card(context).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context)),
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
                        color: isDark ? Colors.white : AppColors.primary(context),
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
    final bool isSelected = _selectedTab == index;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
                  ? (isDark ? AppColors.primary(context) : Colors.white)
                  : (isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textSecondary(context)),
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
      color: AppColors.background(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () async => _onRefresh()),
          SliverPadding(
            padding: const EdgeInsets.only(top: 0),
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
      if (_memberTeventTypeFilter == MemberTeventTypeFilter.real) {
        pendingMembers = pendingMembers
            .where((m) => m.isVirtualUser != true)
            .toList();
      } else if (_memberTeventTypeFilter == MemberTeventTypeFilter.virtual) {
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBg = isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.card(context).withValues(alpha: 0.8);
    final Color barBorder = isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context);

    final Color contentColor = isDark ? Colors.white : AppColors.textPrimary(context);
    final Color contentIconColor = isDark ? Colors.white70 : Colors.black;

    return RepaintBoundary(
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: barBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: barBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Cancel Button
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: contentIconColor,
                  size: 20,
                ),
                onPressed: _toggleSelectionMode,
                tooltip: 'Cancel selection',
              ),

              // Selection Count
              Expanded(
                child: Text(
                  '${_selectedMemberIds.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: contentColor,
                    letterSpacing: 0.3,
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
                  color: contentIconColor,
                  size: 20,
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
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: contentIconColor,
                  size: 20,
                ),
                offset: const Offset(0, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                color: AppColors.card(context),
                enabled: _selectedMemberIds.isNotEmpty,
                onSelected: (value) {
                  final memberProvider = context.read<MemberProvider>();
                  final selectedMembers = memberProvider.members
                      .where((m) => _selectedMemberIds.contains(m.uid))
                      .toList();
                  
                  if (value == 'make_admin') {
                    _showBulkMakeAdminConfirmation(selectedMembers);
                  } else if (value == 'remove_admin') {
                    _showBulkRemoveAdminConfirmation(selectedMembers);
                  } else if (value == 'unapprove') {
                    _showBulkUnapproveConfirmation(selectedMembers);
                  } else if (value == 'remove_community') {
                    _showBulkRemoveConfirmation(selectedMembers);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final memberProvider = context.read<MemberProvider>();
                  final selectedMembers = memberProvider.members
                      .where((m) => _selectedMemberIds.contains(m.uid))
                      .toList();
                  final hasAdmins = selectedMembers.any((m) => m.isAdmin);
                  final hasNonAdmins = selectedMembers.any((m) => !m.isAdmin);

                  return [
                    if (hasNonAdmins)
                      _buildPopupMenuItem(
                        value: 'make_admin',
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Make Admin',
                        color: AppColors.primary(context),
                      ),
                    if (hasAdmins)
                      _buildPopupMenuItem(
                        value: 'remove_admin',
                        icon: Icons.person_remove_alt_1_rounded,
                        label: 'Remove Admin',
                        color: AppColors.warning(context),
                      ),
                    _buildPopupMenuItem(
                      value: 'unapprove',
                      icon: Icons.block_flipped,
                      label: 'Unapprove',
                      color: AppColors.error(context),
                    ),
                    _buildPopupMenuItem(
                      value: 'remove_community',
                      icon: Icons.person_remove_rounded,
                      label: 'Remove Community',
                      color: Colors.purple,
                    ),
                  ];
                },
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
                ? 'No results matching your search for "$_searchQuery"'
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
          : AppColors.background(context),
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
                            color: AppColors.background(context),
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
                        isActive: _memberTeventTypeFilter == MemberTeventTypeFilter.all,
                        onTap: () {
                          setState(
                            () => _memberTeventTypeFilter = MemberTeventTypeFilter.all,
                          );
                          setModalState(() {});
                        },
                      ),
                      _buildFilterChip(
                        label: 'Real Users',
                        isActive: _memberTeventTypeFilter == MemberTeventTypeFilter.real,
                        onTap: () {
                          setState(
                            () => _memberTeventTypeFilter = MemberTeventTypeFilter.real,
                          );
                          setModalState(() {});
                        },
                      ),
                      _buildFilterChip(
                        label: 'Virtual Users',
                        isActive: _memberTeventTypeFilter == MemberTeventTypeFilter.virtual,
                        onTap: () {
                          setState(
                            () => _memberTeventTypeFilter = MemberTeventTypeFilter.virtual,
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





