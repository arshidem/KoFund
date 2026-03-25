import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_styles.dart';
import '../providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'member_details_screen.dart';
import 'package:flutter/services.dart';
import 'package:kofund/core/skeleton/member_list_skeleton.dart';
import 'package:kofund/core/services/virtual_user_service.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';
import 'package:kofund/core/widgets/glass_action_button.dart';
import 'dart:ui';
import 'package:badges/badges.dart' as badges;
import 'package:kofund/features/virtual_users/screens/create_virtual_users_screen.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/core/services/contribution_service.dart';


enum MemberTypeFilter { all, real, virtual }

class MemberFilters {
  MemberTypeFilter typeFilter;

  MemberFilters({this.typeFilter = MemberTypeFilter.all});

  MemberFilters copyWith({
    MemberTypeFilter? typeFilter,
  }) {
    return MemberFilters(
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }

  int get activeCount => typeFilter != MemberTypeFilter.all ? 1 : 0;
}

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
  MemberFilters _filters = MemberFilters();

  // Pagination controller - kept for general scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
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
      _filters = MemberFilters();
    });
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

  Future<void> _loadMembers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final memberProvider = context.read<MemberProvider>();
      await memberProvider.loadMembers(filterType: _filters.typeFilter.name);
      
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
      }
    }
  }

  Future<void> _onRefresh() async {
    try {
      final memberProvider = context.read<MemberProvider>();
      await memberProvider.loadMembers(filterType: _filters.typeFilter.name);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    
    switch (_filters.typeFilter) {
      case MemberTypeFilter.real:
        return filteredBySearch.where((user) => !user.isVirtualUser).toList();
      case MemberTypeFilter.virtual:
        return filteredBySearch.where((user) => user.isVirtualUser).toList();
      case MemberTypeFilter.all:
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        edgeOffset: 120,
        color: AppColors.primary(context),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            _buildFlatSliverAppBar(showBackButton, isAdmin, currentUser),
            if (_filters.typeFilter != MemberTypeFilter.all) _buildActiveFilterChips(),
            if (_searchQuery.isNotEmpty) _buildSearchHeader(filteredMembers.length),
            _buildBodyContent(memberProvider, currentUser, filteredMembers, isAdmin, memberCounts),
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
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
    );
  }

  Widget _buildBodyContent(
    MemberProvider memberProvider,
    UserModel? currentUser,
    List<UserModel> displayedMembers,
    bool isAdmin,
    Map<String, int> memberCounts
  ) {
    if (_isInitialLoad || (_isLoading && displayedMembers.isEmpty)) {
      return MemberListSkeleton.buildSliver(
        context, 
        Theme.of(context).brightness == Brightness.dark,
      );
    }

    if (_errorMessage != null || memberProvider.error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? memberProvider.error!,
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
        ),
      );
    }

    if (displayedMembers.isEmpty && !_refreshController.isRefresh) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final member = displayedMembers[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 400)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: _buildMemberCard(member, currentUser),
          );
        },
        childCount: displayedMembers.length,
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        filters: _filters,
        onFiltersChanged: (newFilters) {
          setState(() {
            _filters = newFilters;
          });
          _loadMembers();
        },
      ),
    );
  }

  Widget _buildFlatSliverAppBar(bool showBackButton, bool isAdmin, UserModel? currentUser) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppColors.background(context);
    
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      // Back button
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 16,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            )
          : null,
      // Approval requests button
      actions: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final pendingCount = userProvider.pendingMembers.length;
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ApprovalRequestsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
                        ),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Center(
                        child: badges.Badge(
                          showBadge: pendingCount > 0,
                          badgeContent: Text(
                            pendingCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          badgeStyle: badges.BadgeStyle(
                            badgeColor: AppColors.error(context),
                            padding: const EdgeInsets.all(4),
                            elevation: 0,
                          ),
                          position: badges.BadgePosition.topEnd(top: -6, end: -6),
                          child: Icon(
                            Icons.person_add_alt_1,
                            size: 18,
                            color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
      // Title with dynamic scaling
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double maxHeight = 220.0;
          final double currentHeight = constraints.biggest.height;
          final double progress = ((currentHeight - 140) / (maxHeight - 140)).clamp(0.0, 1.0);
          final double fontSize = 20 + (2 * progress); // 20 collapsed → 22 expanded
          
          return FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            centerTitle: true,
            titlePadding: const EdgeInsets.only(bottom: 112 + 10),
            title: Text(
              'Members',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                letterSpacing: -0.5 - (0.5 * progress),
              ),
            ),
          );
        },
      ),
      // Pinned search bar at bottom
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(84 + 28),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _isSelectionMode
                  ? _buildFlatSelectionControls(currentUser)
                  : _buildFlatSearchBar(),
            ),
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatSearchBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.search, color: AppColors.textSecondary(context), size: 20),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                      letterSpacing: 0.3,
                    ),
                    cursorColor: AppColors.primary(context),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      hintText: 'Search members...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary(context).withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      isDense: true,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary(context)),
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
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
              width: 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openFilterSheet(context),
              child: Center(
                child: badges.Badge(
                  showBadge: _filters.activeCount > 0,
                  badgeContent: Text(
                    _filters.activeCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.error(context),
                    padding: const EdgeInsets.all(4),
                    elevation: 0,
                  ),
                  position: badges.BadgePosition.topEnd(top: -6, end: -6),
                  child: Icon(Icons.tune, color: AppColors.textSecondary(context), size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlatSelectionControls(UserModel? currentUser) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final memberProvider = context.read<MemberProvider>();
    final allMembers = List<UserModel>.from(memberProvider.members);
    final filteredMembers = _getFilteredMembers(allMembers);
    final isAdmin = currentUser?.isAdmin == true;
    
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: AppColors.primary(context), size: 22),
            onPressed: _toggleSelectionMode,
          ),
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
          IconButton(
            icon: Icon(
              _selectedMemberIds.length == filteredMembers.length - (currentUser != null ? 1 : 0)
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: AppColors.primary(context),
              size: 22,
            ),
            onPressed: _selectedMemberIds.length == filteredMembers.length - (currentUser != null ? 1 : 0)
                ? _clearSelection
                : () => _selectAllMembers(filteredMembers, currentUser),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.primary(context), size: 22),
              onSelected: _handleBulkAction,
              itemBuilder: (context) {
                final selectedMembers = allMembers.where((m) => _selectedMemberIds.contains(m.uid)).toList();
                final filteredSelectedMembers = selectedMembers.where((m) => m.uid != currentUser?.uid).toList();
                
                if (filteredSelectedMembers.isEmpty) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'no_selection',
                      enabled: false,
                      child: Text('No valid members selected', style: TextStyle(color: Colors.grey)),
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
                
                final menuItems = <PopupMenuItem<String>>[];
                
                if (hasNonAdmins) {
                  menuItems.add(PopupMenuItem<String>(
                    value: 'make_admin',
                    child: ListTile(dense: true, leading: Icon(Icons.admin_panel_settings, color: Colors.orange), title: const Text('Make Admin'), subtitle: hasMixedUsers ? const Text('For real users only') : null),
                  ));
                }
                if (hasAdmins) {
                  menuItems.add(PopupMenuItem<String>(
                    value: 'remove_admin',
                    child: ListTile(dense: true, leading: Icon(Icons.person_remove, color: Colors.orange[800]), title: const Text('Remove Admin'), subtitle: hasMixedUsers ? const Text('For real users only') : null),
                  ));
                }
                if (hasRealUsers) {
                  menuItems.add(PopupMenuItem<String>(
                    value: 'unapprove',
                    child: ListTile(dense: true, leading: Icon(Icons.block, color: Colors.red), title: const Text('Unapprove Users'), subtitle: hasMixedUsers ? const Text('For real users only') : null),
                  ));
                }
                menuItems.add(PopupMenuItem<String>(
                  value: 'remove',
                  child: ListTile(
                    dense: true,
                    leading: Icon(hasOnlyVirtualUsers ? Icons.delete : Icons.exit_to_app, color: Colors.red),
                    title: Text(hasOnlyVirtualUsers ? 'Delete Virtual Users' : hasOnlyRealUsers ? 'Remove from Community' : 'Remove/Delete Users'),
                    subtitle: hasMixedUsers ? const Text('Virtual users: Delete, Real users: Remove') : null,
                  ),
                ));
                
                return menuItems;
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    final hasTypeFilter = _filters.typeFilter != MemberTypeFilter.all;
    
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        color: AppColors.background(context),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (hasTypeFilter)
                _buildActiveChip(
                  _filters.typeFilter.name.toUpperCase(),
                  () {
                    setState(() {
                      _filters = _filters.copyWith(typeFilter: MemberTypeFilter.all);
                    });
                    _loadMembers();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onDeleted) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(context),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDeleted,
            child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(int resultCount) {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary(context).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary(context).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: AppColors.primary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search results for "$_searchQuery"',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$resultCount ${resultCount == 1 ? 'member' : 'members'}',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Selection controls are now integrated into _buildFlatSelectionControls

  Widget _buildEmptyState() {
    final isAdmin = context.read<AppAuthProvider>().user?.isAdmin == true;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary(context).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _searchQuery.isNotEmpty ? Icons.person_search_outlined : Icons.people_outline,
            size: 64,
            color: AppColors.primary(context),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _searchQuery.isNotEmpty ? 'No matches found' : 'No members yet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _searchQuery.isNotEmpty 
                ? 'We couldn\'t find any members matching "$_searchQuery". Try adjusting your filters or search terms.'
                : 'When members join and get approved, or when you add virtual members, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        if (_searchQuery.isEmpty && isAdmin) ...[
          const SizedBox(height: 32),
          _buildAddVirtualUserButton(),
        ],
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              FocusScope.of(context).unfocus();
            },
            icon: const Icon(Icons.clear_all, size: 20),
            label: const Text(
              'Clear Search',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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
          backgroundColor: AppColors.primary(context),
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
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
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
                            color: AppColors.primary(context).withValues(alpha: 0.12),
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
                              _buildChip('Virtual', AppColors.primary(context)),
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

  // _buildModernSearchBar is replaced by _buildFlatSearchBar above

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

class FilterSheet extends StatefulWidget {
  final MemberFilters filters;
  final Function(MemberFilters) onFiltersChanged;

  const FilterSheet({
    Key? key,
    required this.filters,
    required this.onFiltersChanged,
  }) : super(key: key);

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> with SingleTickerProviderStateMixin {
  late MemberFilters _currentFilters;
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _currentFilters = MemberFilters(
      typeFilter: widget.filters.typeFilter,
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animationController != null
        ? CurvedAnimation(parent: _animationController!, curve: Curves.easeOutQuart)
        : null;

    final content = Container(
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Members',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final freshFilters = MemberFilters();
                      setState(() {
                        _currentFilters = freshFilters;
                      });
                      widget.onFiltersChanged(freshFilters);
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error(context),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Member Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _typeChip('All', MemberTypeFilter.all),
                  _typeChip('Real', MemberTypeFilter.real),
                  _typeChip('Virtual', MemberTypeFilter.virtual),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onFiltersChanged(_currentFilters);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (animation == null) return content;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  Widget _typeChip(String label, MemberTypeFilter type) {
    final isSelected = _currentFilters.typeFilter == type;
    final primaryColor = AppColors.primary(context);
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isSelected) {
            _currentFilters = _currentFilters.copyWith(typeFilter: MemberTypeFilter.all);
          } else {
            _currentFilters = _currentFilters.copyWith(typeFilter: type);
          }
        });
      },
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary(context),
      ),
      backgroundColor: AppColors.card(context),
      selectedColor: primaryColor,
      elevation: isSelected ? 4 : 0,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      pressElevation: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppColors.border(context).withValues(alpha: 0.5),
        ),
      ),
      showCheckmark: false,
    );
  }
}
