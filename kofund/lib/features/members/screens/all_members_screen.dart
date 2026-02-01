import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/constants/app_colors.dart';
import '../providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'member_details_screen.dart';
import 'package:flutter/services.dart';
import 'package:kofund/core/skeleton/member_list_skeleton.dart';
import 'package:kofund/features/virtual_users/screens/create_virtual_users_screen.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/core/services/contribution_service.dart';
import 'package:kofund/core/services/virtual_user_service.dart';
import 'dart:ui';

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
        userService: Provider.of<UserService>(context, listen: false),
        authProvider: auth,
        participantService: Provider.of<ParticipantService>(context, listen: false),
        contributionService: Provider.of<ContributionService>(context, listen: false),
        virtualUserService: VirtualUserService(),
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
  
  // Add this getter in your state class
  List<UserModel> get _members {
    final memberProvider = context.read<MemberProvider>();
    return memberProvider.members;
  }
  
  // Selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedMemberIds = <String>{};
  
  // Refresh controller
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  
  // Loading states
  bool _isInitialLoad = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Track user
  String? _currentUserId;

  // Filter state
  String _selectedFilter = 'all'; // 'all', 'real', 'virtual'

  // Pagination controller
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    
    // Setup scroll listener for pagination
    _scrollController.addListener(_scrollListener);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadMembers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    // Check if user has changed
    if (user != null && user.uid != _currentUserId) {
      _currentUserId = user.uid;
      _resetScreenForNewUser();
      
      if (mounted) {
        _checkAuthAndLoadMembers();
      }
    }
    
    if (user != null && _isInitialLoad && _currentUserId == null) {
      _currentUserId = user.uid;
      _checkAuthAndLoadMembers();
    }
  }

  void _resetScreenForNewUser() {
    if (!mounted) return;
    
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSelectionMode = false;
      _selectedMemberIds.clear();
      _isInitialLoad = true;
      _isLoading = false;
      _errorMessage = null;
      _selectedFilter = 'all';
      _isLoadingMore = false;
    });
    
    final memberProvider = context.read<MemberProvider>();
    memberProvider.resetPagination();
  }

  void _checkAuthAndLoadMembers() {
    if (!mounted) return;
    
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    if (user == null) {
      setState(() {
        _isInitialLoad = false;
        _isLoading = false;
        _errorMessage = 'Please sign in to view members';
      });
      return;
    }
    
    if (user.communityId == null) {
      setState(() {
        _isInitialLoad = false;
        _isLoading = false;
        _errorMessage = 'You are not part of any community';
      });
      return;
    }
    
    _loadMembers();
  }

  Future<void> _loadMembers({bool loadMore = false}) async {
    if (!mounted) return;
    
    setState(() {
      if (!loadMore) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _errorMessage = null;
    });
    
    try {
      final memberProvider = context.read<MemberProvider>();
      
      if (loadMore) {
        await memberProvider.loadMoreMembers(filterType: _selectedFilter);
      } else {
        await memberProvider.loadMembers(filterType: _selectedFilter);
      }
      
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Failed to load members: $error';
        });
      }
    }
  }

  void _onRefresh() async {
    try {
      final memberProvider = context.read<MemberProvider>();
      await memberProvider.loadMembers(filterType: _selectedFilter);
      
      _refreshController.refreshCompleted();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _refreshController.refreshFailed();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollListener() {
    final memberProvider = context.read<MemberProvider>();
    
    if (_scrollController.position.pixels == 
        _scrollController.position.maxScrollExtent &&
        memberProvider.hasMoreData &&
        !_isLoadingMore &&
        !memberProvider.isLoading) {
      _loadMembers(loadMore: true);
    }
  }

  void _navigateToCreateVirtualUsers() {
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    if (user == null || user.communityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be in a community'),
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateVirtualUsersScreen(
          communityId: user.communityId!,
          communityName: user.communityName ?? 'Community',
        ),
      ),
    ).then((createdCount) {
      if (createdCount != null && createdCount > 0) {
        // Refresh members list
        context.read<MemberProvider>().loadMembers(reset: true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully added $createdCount virtual members'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  List<UserModel> _getFilteredMembers(List<UserModel> allMembers) {
    List<UserModel> filteredBySearch = _searchQuery.isEmpty
        ? allMembers
        : allMembers.where((user) {
            return user.displayName?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
                   user.phoneNumber?.contains(_searchQuery) == true ||
                   user.email?.toLowerCase().contains(_searchQuery.toLowerCase()) == true;
          }).toList();
    
    switch (_selectedFilter) {
      case 'real':
        return filteredBySearch.where((user) => !user.isVirtualUser).toList();
      case 'virtual':
        return filteredBySearch.where((user) => user.isVirtualUser).toList();
      default:
        return filteredBySearch;
    }
  }

  Map<String, int> _getMemberCounts(List<UserModel> allMembers) {
    final realCount = allMembers.where((m) => !m.isVirtualUser).length;
    final virtualCount = allMembers.where((m) => m.isVirtualUser).length;
    
    return {
      'all': allMembers.length,
      'real': realCount,
      'virtual': virtualCount,
    };
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMemberIds.clear();
      }
    });
  }

  void _toggleMemberSelection(String memberId, bool isCurrentUser) {
    if (isCurrentUser) return;
    
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

  void _selectAllMembers(List<UserModel> members, UserModel? currentUser) {
    final filteredMembers = members.where((member) => member.uid != currentUser?.uid).toList();
    
    setState(() {
      if (_selectedMemberIds.length == filteredMembers.length) {
        _selectedMemberIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedMemberIds.clear();
        _selectedMemberIds.addAll(filteredMembers.map((m) => m.uid));
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMemberIds.clear();
      _isSelectionMode = false;
    });
  }

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

  // =================== BULK ACTION METHODS ===================
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

  void _showBulkRemoveConfirmation(List<UserModel> members, {bool forVirtualUsers = false}) {
    final title = forVirtualUsers ? 'Delete Virtual Users?' : 'Remove from Community?';
    final actionText = forVirtualUsers ? 'Delete' : 'Remove';
    final message = forVirtualUsers 
        ? 'Are you sure you want to delete ${members.length} virtual user${members.length > 1 ? 's' : ''}? This action cannot be undone.'
        : 'Are you sure you want to remove ${members.length} user${members.length > 1 ? 's' : ''} from the community?';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text(
          message,
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
              if (forVirtualUsers) {
                _bulkDeleteVirtualUsers(members);
              } else {
                _bulkRemoveFromCommunity(members);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(actionText),
          ),
        ],
      ),
      useRootNavigator: true,
    );
  }

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

  void _bulkDeleteVirtualUsers(List<UserModel> members) async {
    final memberProvider = context.read<MemberProvider>();
    final uids = members.map((m) => m.uid).toList();
    
    final success = await memberProvider.bulkDeleteVirtualUsers(uids);
    
    if (success && mounted) {
      setState(() {
        _clearSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${members.length} virtual users'),
          backgroundColor: Colors.green,
        ),
      );
      _loadMembers();
    }
  }

  // Handle bulk action selection
  void _handleBulkAction(String action) {
    final memberProvider = context.read<MemberProvider>();
    final currentUser = context.read<AppAuthProvider>().user;
    
    final allMembers = List<UserModel>.from(memberProvider.members);
    final selectedMembers = allMembers.where((m) => _selectedMemberIds.contains(m.uid)).toList();
    
    // Filter out current user from selected members
    final filteredSelectedMembers = selectedMembers.where((m) => m.uid != currentUser?.uid).toList();
    
    if (filteredSelectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid members selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check selection type
    final hasVirtualUsers = filteredSelectedMembers.any((m) => m.isVirtualUser);
    final hasRealUsers = filteredSelectedMembers.any((m) => !m.isVirtualUser);
    final hasNonAdmins = filteredSelectedMembers.any((m) => !m.isAdmin && !m.isVirtualUser);
    final hasAdmins = filteredSelectedMembers.any((m) => m.isAdmin && !m.isVirtualUser);

    switch (action) {
      case 'make_admin':
        if (!hasNonAdmins) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No non-admin real users selected'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _showBulkMakeAdminConfirmation(filteredSelectedMembers.where((m) => !m.isAdmin && !m.isVirtualUser).toList());
        break;
        
      case 'remove_admin':
        if (!hasAdmins) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No admin users selected'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _showBulkRemoveAdminConfirmation(filteredSelectedMembers.where((m) => m.isAdmin && !m.isVirtualUser).toList());
        break;
        
      case 'unapprove':
        // Filter out virtual users (can't unapprove virtual users)
        final realUsersToUnapprove = filteredSelectedMembers.where((m) => !m.isVirtualUser).toList();
        if (realUsersToUnapprove.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Virtual users cannot be unapproved'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _showBulkUnapproveConfirmation(realUsersToUnapprove);
        break;
        
      case 'remove':
        // Check if selection has mixed users
        if (hasVirtualUsers && hasRealUsers) {
          // Show combined remove action for both types
          _showBulkRemoveConfirmation(filteredSelectedMembers);
        } else if (hasVirtualUsers) {
          // Only virtual users - show delete confirmation
          _showBulkRemoveConfirmation(filteredSelectedMembers, forVirtualUsers: true);
        } else {
          // Only real users - show remove from community
          _showBulkRemoveConfirmation(filteredSelectedMembers);
        }
        break;
    }
  }

  @override
Widget build(BuildContext context) {
  final bool showBackButton = widget.forceBackButton ?? 
      (ModalRoute.of(context)?.canPop ?? false);

  final memberProvider = context.watch<MemberProvider>();
  final currentUser = context.watch<AppAuthProvider>().user;
  final isAdmin = currentUser?.isAdmin == true;

  final allMembers = memberProvider.members;
  final filteredMembers = _getFilteredMembers(allMembers);
  final memberCounts = _getMemberCounts(allMembers);

  return Scaffold(
    backgroundColor: AppColors.background(context),
    appBar: AppBar(
      title: const Text(
        'Members',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
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
              ? _buildSelectionControls(filteredMembers, isAdmin, currentUser)
              : _buildSearchBar(),
        ),
      ),
    ),

    body: SafeArea(
      child: Column(
        children: [
          // Fixed filter tabs below AppBar
          Container(
            margin: const EdgeInsets.only(right: 16, left: 16, top: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildMemberTab("All", 'all'),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildMemberTab("Real", 'real'),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildMemberTab("Virtual", 'virtual'),
                ),
              ],
            ),
          ),
          
          // Scrollable content
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
                completeIcon: const Icon(Icons.check, color: Colors.green),
                failedIcon: const Icon(Icons.error, color: Colors.red),
              ),
              child: _buildContent(memberProvider, currentUser, filteredMembers, isAdmin, memberCounts),
            ),
          ),
        ],
      ),
    ),
    
    floatingActionButton: isAdmin ? _buildVirtualUserFAB() : null,
  );
}

  Widget _buildVirtualUserFAB() {
    return FloatingActionButton.extended(
      onPressed: _navigateToCreateVirtualUsers,
      backgroundColor: AppColors.primary(context),
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.person_add, size: 22),
      label: const Text('Add Virtual'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildContent(
    MemberProvider memberProvider,
    UserModel? currentUser,
    List<UserModel> displayedMembers,
    bool isAdmin,
    Map<String, int> memberCounts
  ) {
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
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

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        // Search Header
        if (_searchQuery.isNotEmpty) _buildSearchHeader(displayedMembers.length),

        // Provider Error
        if (memberProvider.error != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        memberProvider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => memberProvider.clearError(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Members List
        if (displayedMembers.isEmpty && !_refreshController.isRefresh)
          _buildEmptyState()
        else ...[
          ...displayedMembers.map((member) => _buildMemberCard(member, currentUser)).toList(),
          
          // Pagination Loader
          if (_isLoadingMore || memberProvider.isLoadingMore)
            _buildPaginationLoader(),
            
          // No More Data
          if (!memberProvider.hasMoreData && displayedMembers.isNotEmpty)
            _buildNoMoreData(),
        ],
      ],
    );
  }

  Widget _buildMemberTab(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        _loadMembers();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            _buildTabCount(value, isSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildTabCount(String value, bool isSelected) {
    final memberCounts = _getMemberCounts(_members);
    int count = 0;
    
    switch (value) {
      case 'all':
        count = memberCounts['all'] ?? 0;
        break;
      case 'real':
        count = memberCounts['real'] ?? 0;
        break;
      case 'virtual':
        count = memberCounts['virtual'] ?? 0;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.card(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textSecondary(context),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(int resultCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.06),
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

  Widget _buildSelectionControls(List<UserModel> displayedMembers, bool isAdmin, UserModel? currentUser) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.card(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Cancel Button
          IconButton(
            icon: Icon(Icons.close, color: AppColors.primary(context), size: 22),
            onPressed: _toggleSelectionMode,
          ),
          
          // Selection Count
          Expanded(
            child: Text(
              '${_selectedMemberIds.length} selected',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.primary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Select All / Deselect All
          IconButton(
            icon: Icon(
              _selectedMemberIds.length == displayedMembers.length - (currentUser != null ? 1 : 0)
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: AppColors.primary(context),
              size: 22,
            ),
            onPressed: _selectedMemberIds.length == displayedMembers.length - (currentUser != null ? 1 : 0)
                ? _clearSelection
                : () => _selectAllMembers(displayedMembers, currentUser),
          ),
          
          // Bulk Actions Menu
          if (isAdmin)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.primary(context), size: 22),
              onSelected: _handleBulkAction,
              itemBuilder: (context) {
                final memberProvider = context.read<MemberProvider>();
                final allMembers = List<UserModel>.from(memberProvider.members);
                final selectedMembers = allMembers.where((m) => _selectedMemberIds.contains(m.uid)).toList();
                
                // Filter out current user
                final filteredSelectedMembers = selectedMembers.where((m) => m.uid != currentUser?.uid).toList();
                
                if (filteredSelectedMembers.isEmpty) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'no_selection',
                      enabled: false,
                      child: Text(
                        'No valid members selected',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ];
                }
                
                final hasVirtualUsers = filteredSelectedMembers.any((m) => m.isVirtualUser);
                final hasRealUsers = filteredSelectedMembers.any((m) => !m.isVirtualUser);
                final hasNonAdmins = filteredSelectedMembers.any((m) => !m.isAdmin && !m.isVirtualUser);
                final hasAdmins = filteredSelectedMembers.any((m) => m.isAdmin && !m.isVirtualUser);
                final hasOnlyVirtualUsers = hasVirtualUsers && !hasRealUsers;
                final hasOnlyRealUsers = hasRealUsers && !hasVirtualUsers;
                final hasMixedUsers = hasVirtualUsers && hasRealUsers;
                
                // Build menu items
                final menuItems = <PopupMenuItem<String>>[];
                
                // Make Admin (only for real non-admin users)
                if (hasNonAdmins) {
                  menuItems.add(
                    PopupMenuItem<String>(
                      value: 'make_admin',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.admin_panel_settings, color: Colors.orange),
                        title: const Text('Make Admin'),
                        subtitle: hasMixedUsers ? const Text('For real users only') : null,
                      ),
                    ),
                  );
                }
                
                // Remove Admin (only for real admin users)
                if (hasAdmins) {
                  menuItems.add(
                    PopupMenuItem<String>(
                      value: 'remove_admin',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.person_remove, color: Colors.orange[800]),
                        title: const Text('Remove Admin'),
                        subtitle: hasMixedUsers ? const Text('For real users only') : null,
                      ),
                    ),
                  );
                }
                
                // Unapprove (only for real users)
                if (hasRealUsers) {
                  menuItems.add(
                    PopupMenuItem<String>(
                      value: 'unapprove',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.block, color: Colors.red),
                        title: const Text('Unapprove Users'),
                        subtitle: hasMixedUsers ? const Text('For real users only') : null,
                      ),
                    ),
                  );
                }
                
                // Remove/Delete action
                menuItems.add(
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        hasOnlyVirtualUsers ? Icons.delete : Icons.exit_to_app,
                        color: Colors.red,
                      ),
                      title: Text(
                        hasOnlyVirtualUsers 
                            ? 'Delete Virtual Users'
                            : hasOnlyRealUsers
                                ? 'Remove from Community'
                                : 'Remove/Delete Users',
                      ),
                      subtitle: hasMixedUsers 
                          ? const Text('Virtual users: Delete, Real users: Remove')
                          : null,
                    ),
                  ),
                );
                
                return menuItems;
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isAdmin = context.read<AppAuthProvider>().user?.isAdmin == true;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 120),
        Icon(
          _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
          size: 64,
          color: AppColors.primary(context).withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          _searchQuery.isNotEmpty ? 'No results found' : 'No members available',
          style: TextStyle(
            fontSize: 18,
            color: AppColors.primary(context).withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _searchQuery.isNotEmpty 
              ? 'No matches for "$_searchQuery"'
              : 'When members join and get approved,\nthey will appear here.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
        if (_searchQuery.isEmpty && isAdmin) ...[
          const SizedBox(height: 24),
          _buildAddVirtualUserButton(),
        ],
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Search'),
          ),
        ],
      ],
    );
  }

  Widget _buildAddVirtualUserButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: ElevatedButton.icon(
        onPressed: _navigateToCreateVirtualUsers,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.person_add, size: 22),
        label: const Text(
          'Add Virtual Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationLoader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildNoMoreData() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No more members',
          style: TextStyle(
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(UserModel member, UserModel? currentUser) {
    final isCurrentUser = currentUser?.uid == member.uid;
    final isSelected = _selectedMemberIds.contains(member.uid);
    final isAdmin = currentUser?.isAdmin == true;
    final hasPhoneNumber = member.phoneNumber != null && member.phoneNumber!.isNotEmpty;
    final isVirtualUser = member.isVirtualUser;
    
    final contactInfo = member.phoneNumber ?? member.email ?? 'No contact info';

    return Column(
      children: [
        Material(
          color: isSelected 
              ? AppColors.primary(context).withValues(alpha: 0.12) 
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_isSelectionMode && isAdmin && !isCurrentUser) {
                setState(() => _toggleMemberSelection(member.uid, isCurrentUser));
              } else {
                _navigateToMemberDetails(member);
              }
            },
            onLongPress: isAdmin && !isCurrentUser ? () {
              setState(() {
                if (!_isSelectionMode) _isSelectionMode = true;
                _toggleMemberSelection(member.uid, isCurrentUser);
              });
            } : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isVirtualUser 
                                ? Colors.purple.withValues(alpha: 0.12)
                                : AppColors.primary(context).withValues(alpha: 0.12),
                          ),
                          child: Center(
                            child: Text(
                              (member.displayName?.isNotEmpty == true 
                                  ? member.displayName![0].toUpperCase() 
                                  : '?'),
                              style: TextStyle(
                                color: isVirtualUser 
                                    ? Colors.purple[800]
                                    : AppColors.primary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        
                        if (_isSelectionMode && isAdmin && !isCurrentUser)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _toggleMemberSelection(member.uid, isCurrentUser));
                              },
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary(context)
                                      : AppColors.card(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary(context)
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
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
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            
                            if (isCurrentUser)
                              _buildChip('You', Colors.blue),
                            
                            if (member.isAdmin && !isCurrentUser) 
                              _buildChip('Admin', Colors.orange[800]!),
                            
                            if (isVirtualUser)
                              _buildChip('Virtual', Colors.purple),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contactInfo,
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
                  
                  SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: (!_isSelectionMode && hasPhoneNumber)
                          ? InkResponse(
                              radius: 20,
                              onTap: () => _makePhoneCall(member.phoneNumber!),
                              child: Icon(
                                Icons.phone,
                                size: 20,
                                color: AppColors.primary(context),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border(context),
        ),
      ],
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      if (cleanedNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid phone number'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final url = Uri.parse('tel:$cleanedNumber');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        if (!mounted) return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot make calls from this device'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
