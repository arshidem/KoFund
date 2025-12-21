// lib/features/members/screens/all_members_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import '../providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'member_details_screen.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:kofund/core/skeleton/member_list_skeleton.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/core/services/contribution_service.dart';
// =================== MAIN SCREEN ===================
class AllMembersScreen extends StatelessWidget {
  final bool? forceBackButton;

  const AllMembersScreen({
    super.key,
    this.forceBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    return ChangeNotifierProvider(
      create: (_) => MemberProvider(
        userService: UserService(),
        authProvider: auth,
        participantService: ParticipantService(),
        contributionService: ContributionService(),
      ),
      child: _AllMembersScreenBody(forceBackButton: forceBackButton),
    );
  }
}

// =================== SCREEN BODY ===================
class _AllMembersScreenBody extends StatefulWidget {
  final bool? forceBackButton;

  const _AllMembersScreenBody({Key? key, this.forceBackButton}) : super(key: key);

  @override
  State<_AllMembersScreenBody> createState() => _AllMembersScreenBodyState();
}

// =================== SCREEN STATE ===================
class _AllMembersScreenBodyState extends State<_AllMembersScreenBody> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Selection mode variables
  bool _isSelectionMode = false;
  final Set<String> _selectedMemberIds = <String>{};
  
  // Pull to refresh controller
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  
  // Add these to track authentication state
  bool _isInitialLoad = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Track current user ID to detect user changes
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: AllMembersScreen initState called');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadMembers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
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
    
    print('🔍 DEBUG: Checking auth state - UID: ${user?.uid}, Community: ${user?.communityId}, Approved: ${user?.isApproved}');
    
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
      await memberProvider.loadApprovedMembers();
      
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoading = false;
        });
        print('✅ DEBUG: Members loaded successfully: ${memberProvider.members.length}');
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
    print('🔄 DEBUG: Pull to refresh triggered');
    
    try {
      final memberProvider = context.read<MemberProvider>();
      await memberProvider.loadApprovedMembers();
      
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
    setState(() {
      if (_selectedMemberIds.length == members.length) {
        _selectedMemberIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedMemberIds.clear();
        _selectedMemberIds.addAll(members.map((m) => m.uid));
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
    final selectedMembers = members.where((m) => selectedIds.contains(m.uid)).toList();

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
                child: Text(
                  'Close',
                  style: TextStyle(color: textSecondary),
                ),
              )
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
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                      color: Colors.white.withOpacity(.85),
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
              subtitle: "Make ${selectedMembers.where((m) => !m.isAdmin).length} user(s) admin",
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
              subtitle: "Remove admin role from ${selectedMembers.where((m) => m.isAdmin).length} user(s)",
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
            backgroundColor: iconColor.withOpacity(.12),
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
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
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

  void _showBulkMakeAdminConfirmation(List<UserModel> members) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make Users Admin?', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text(
          'Are you sure you want to make ${members.length} user${members.length > 1 ? 's' : ''} admin?',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        backgroundColor: AppColors.card(context),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _bulkMakeAdmin(members);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary(context)),
            child: const Text('Make Admin'),
          ),
        ],
      ),
      useRootNavigator: true,
    );
  }

  void _showBulkRemoveAdminConfirmation(List<UserModel> members) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Admin Role?', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text(
          'Are you sure you want to remove admin role from ${members.length} user${members.length > 1 ? 's' : ''}?',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        backgroundColor: AppColors.card(context),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _bulkRemoveAdmin(members);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remove Admin'),
          ),
        ],
      ),
      useRootNavigator: true,
    );
  }

  void _showBulkUnapproveConfirmation(List<UserModel> members) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unapprove Users?', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text(
          'Are you sure you want to unapprove ${members.length} user${members.length > 1 ? 's' : ''}?',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        backgroundColor: AppColors.card(context),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _bulkUnapproveUsers(members);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unapprove'),
          ),
        ],
      ),
      useRootNavigator: true,
    );
  }

  void _showBulkRemoveConfirmation(List<UserModel> members) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove from Community?', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text(
          'Are you sure you want to remove ${members.length} user${members.length > 1 ? 's' : ''} from the community?',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        backgroundColor: AppColors.card(context),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _bulkRemoveFromCommunity(members);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
      useRootNavigator: true,
    );
  }

  // ✅ BULK ACTION IMPLEMENTATIONS
  void _bulkMakeAdmin(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();
    
    final success = await memberProvider.bulkUpdateMemberRoles(uids, true);
    
    if (success && mounted) {
      setState(() {
        _clearSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Made ${members.length} users admin'),
          backgroundColor: Colors.green,
        ),
      );
      _loadMembers();
    }
  }

  void _bulkRemoveAdmin(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();
    
    final success = await memberProvider.bulkUpdateMemberRoles(uids, false);
    
    if (success && mounted) {
      setState(() {
        _clearSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed admin role from ${members.length} users'),
          backgroundColor: Colors.green,
        ),
      );
      _loadMembers();
    }
  }

  void _bulkUnapproveUsers(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();
    
    final success = await memberProvider.bulkUnapproveUsers(uids);
    
    if (success && mounted) {
      setState(() {
        _clearSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unapproved ${members.length} users'),
          backgroundColor: Colors.green,
        ),
      );
      _loadMembers();
    }
  }

  void _bulkRemoveFromCommunity(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();
    
    final success = await memberProvider.bulkRemoveFromCommunity(uids);
    
    if (success && mounted) {
      setState(() {
        _clearSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${members.length} users from community'),
          backgroundColor: Colors.green,
        ),
      );
      _loadMembers();
    }
  }

  // ✅ NAVIGATION METHOD
  void _navigateToMemberDetails(UserModel member) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberDetailsScreen(member: member),
      ),
    );
    
    if (mounted) {
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final memberProvider = context.watch<MemberProvider>();
    final currentUser = context.watch<AppAuthProvider>().user;
    final isAdmin = currentUser?.isAdmin == true;

    final displayedMembers = _searchQuery.isEmpty
        ? memberProvider.members
        : memberProvider.searchMembers(_searchQuery);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      // 🎯 SMART APP BAR WITH SEARCH BAR
      appBar: AppBar(
         title: const Text(
    'Members',
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
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: _isSelectionMode
                ? _buildSelectionControls(displayedMembers, isAdmin)
                : _buildModernSearchBar(),
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
        child: _buildContentWithoutSearch(memberProvider, currentUser, displayedMembers, isAdmin),
      ),
    );
  }

  Widget _buildContentWithoutSearch(MemberProvider memberProvider, UserModel? currentUser, 
                      List<UserModel> displayedMembers, bool isAdmin) {
    // Show skeleton when loading and no members to display
    if (_isInitialLoad || (_isLoading && displayedMembers.isEmpty)) {
      return MemberListSkeleton(
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkAuthAndLoadMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Use a simple ListView instead of Column + Expanded + ListView
    return _buildMembersListContent(displayedMembers, currentUser, memberProvider);
  }

  Widget _buildMembersListContent(List<UserModel> displayedMembers, UserModel? currentUser, MemberProvider memberProvider) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // Search Header (like history screen)
        if (_searchQuery.isNotEmpty) _buildSearchHeader(displayedMembers.length),

        // Provider Error Message
        if (memberProvider.error != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        memberProvider.error!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () => memberProvider.clearError(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Show loading indicator during refresh (optional)
        if (_isLoading && _refreshController.isRefresh) ...[
          LinearProgressIndicator(
            color: AppColors.primary(context),
            backgroundColor: AppColors.primary(context).withOpacity(0.2),
          ),
          const SizedBox(height: 8),
        ],

        // Members List
        if (displayedMembers.isEmpty && !_refreshController.isRefresh)
          _buildEmptyState()
        else
          ...displayedMembers.map((member) => _buildMemberCard(member, currentUser)).toList(),
      ],
    );
  }

Widget _buildModernSearchBar() {
  return Container(
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
            contentPadding: const EdgeInsets.fromLTRB(10, 18, 6, 2), // Changed: Increased left padding to 60
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

  // ✅ SEARCH HEADER
  Widget _buildSearchHeader(int resultCount) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withOpacity(0.06),
        borderRadius: BorderRadius.circular(50),
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

  // ✅ SELECTION CONTROLS WIDGET
  Widget _buildSelectionControls(List<UserModel> displayedMembers, bool isAdmin) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.card(context).withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
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
              // Cancel Button
              IconButton(
                icon: Icon(Icons.close, color: AppColors.primary(context), size: 22),
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
                  _selectedMemberIds.length == displayedMembers.length
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: AppColors.primary(context),
                  size: 22,
                ),
                onPressed: _selectedMemberIds.length == displayedMembers.length
                    ? _clearSelection
                    : () => _selectAllMembers(displayedMembers),
                tooltip: _selectedMemberIds.length == displayedMembers.length
                    ? 'Deselect all'
                    : 'Select all',
              ),
              
              // Actions Menu
              IconButton(
                icon: Icon(Icons.more_vert, color: AppColors.primary(context), size: 22),
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
              color: AppColors.primary(context).withOpacity(0.5)
            ),
          )
        else
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.primary(context).withOpacity(0.5),
          ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _searchQuery.isNotEmpty ? 'No results found' : 'No members available',
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
            _searchQuery.isNotEmpty 
                ? 'No matches for "$_searchQuery"'
                : 'When members join and get approved,\nthey will appear here.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Clear Search'),
            ),
          ),
        ],
      ],
    );
  }

 Widget _buildMemberCard(UserModel member, UserModel? currentUser) {
    final isSelected = _selectedMemberIds.contains(member.uid);
    final isAdmin = currentUser?.isAdmin == true;

    // Determine which contact info to display
    final String contactInfo;
    if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty) {
      contactInfo = member.phoneNumber!;
    } else if (member.email != null && member.email!.isNotEmpty) {
      contactInfo = member.email!;
    } else {
      contactInfo = 'No contact info';
    }

    return Column(
      children: [
        Material(
          color: isSelected 
              ? AppColors.primary(context).withOpacity(0.12) 
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_isSelectionMode && isAdmin) {
                setState(() {
                  _toggleMemberSelection(member.uid);
                });
              } else {
                _navigateToMemberDetails(member);
              }
            },
            onLongPress: isAdmin ? () {
              setState(() {
                if (!_isSelectionMode) {
                  _isSelectionMode = true;
                }
                _toggleMemberSelection(member.uid);
              });
            } : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar with selection indicator
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary(context).withOpacity(0.12),
                        ),
                        child: Center(
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
                      ),
                      if (_isSelectionMode)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary(context) : Colors.grey[400],
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.card(context), width: 2),
                            ),
                            child: Icon(
                              isSelected ? Icons.check : Icons.circle_outlined,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  
                  // Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.displayName ?? 'No Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 8),
                            if (member.isAdmin) 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contactInfo, // Shows phone number if available, otherwise email
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(context)
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Chevron only
                  if (!_isSelectionMode) 
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary(context),
                      size: 20,
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
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}