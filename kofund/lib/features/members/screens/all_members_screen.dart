import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

  void _toggleMemberSelection(String memberId, bool isCurrentUser) {
    if (isCurrentUser) return; // Prevent selecting current user
    
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
                ? _buildSelectionControls(displayedMembers, isAdmin, currentUser)
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
    shrinkWrap: true, // Add this
    children: [
      // Search Header (like history screen)
      if (_searchQuery.isNotEmpty) _buildSearchHeader(displayedMembers.length),

      // Provider Error Message
      if (memberProvider.error != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        Container(
          height: 4,
          child: LinearProgressIndicator(
            color: AppColors.primary(context),
            backgroundColor: AppColors.primary(context).withOpacity(0.2),
          ),
        ),
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
Widget _buildSelectionControls(List<UserModel> displayedMembers, bool isAdmin, UserModel? currentUser) {
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
                _selectedMemberIds.length == displayedMembers.length - (currentUser != null ? 1 : 0)
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: AppColors.primary(context),
                size: 22,
              ),
              onPressed: _selectedMemberIds.length == displayedMembers.length - (currentUser != null ? 1 : 0)
                  ? _clearSelection
                  : () => _selectAllMembers(displayedMembers, currentUser),
              tooltip: _selectedMemberIds.length == displayedMembers.length - (currentUser != null ? 1 : 0)
                  ? 'Deselect all'
                  : 'Select all',
            ),
            
            // Actions Menu (three-dot icon) - DIRECT BULK ACTIONS
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.primary(context), size: 22),
              onSelected: (value) {
                _handleBulkActionDirect(value);
              },
              itemBuilder: (context) {
                final memberProvider = context.read<MemberProvider>();
                final currentMembers = List<UserModel>.from(memberProvider.members);
                final selectedMembers = currentMembers.where((m) => _selectedMemberIds.contains(m.uid)).toList();
                
                // Filter out current user from selected members
                final filteredSelectedMembers = selectedMembers.where((m) => m.uid != currentUser?.uid).toList();
                
                if (filteredSelectedMembers.isEmpty) {
                  return [
                    PopupMenuItem<String>(
                      value: 'no_selection',
                      enabled: false,
                      child: Text(
                        'No valid members selected',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ];
                }

                final hasNonAdmins = filteredSelectedMembers.any((m) => !m.isAdmin);
                final hasAdmins = filteredSelectedMembers.any((m) => m.isAdmin);

                return [
                  // Make Admin
                  PopupMenuItem<String>(
                    value: 'make_admin',
                    enabled: hasNonAdmins,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.admin_panel_settings, 
                          color: hasNonAdmins ? AppColors.primary(context) : Colors.grey),
                      title: Text(
                        'Make Admin',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: hasNonAdmins ? AppColors.textPrimary(context) : Colors.grey,
                        ),
                      ),
                    
                    ),
                  ),
                  
                  // Remove Admin
                  PopupMenuItem<String>(
                    value: 'remove_admin',
                    enabled: hasAdmins,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.person_remove_alt_1, 
                          color: hasAdmins ? Colors.orange : Colors.grey),
                      title: Text(
                        'Remove Admin',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: hasAdmins ? AppColors.textPrimary(context) : Colors.grey,
                        ),
                      ),
                   
                    ),
                  ),
                  
                  // Unapprove Users
                  PopupMenuItem<String>(
                    value: 'unapprove',
                    enabled: true,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.block, color: Colors.red),
                      title: Text(
                        'Unapprove Users',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                   
                    ),
                  ),
                  
                  // Remove from Community
                  PopupMenuItem<String>(
                    value: 'remove',
                    enabled: true,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.exit_to_app, color: Colors.purple),
                      title: Text(
                        'Remove from Community',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                  
                    ),
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

// ✅ HANDLE DIRECT BULK ACTIONS
void _handleBulkActionDirect(String action) {
  final memberProvider = context.read<MemberProvider>();
  final currentUser = context.read<AppAuthProvider>().user;
  
  final currentMembers = List<UserModel>.from(memberProvider.members);
  final selectedMembers = currentMembers.where((m) => _selectedMemberIds.contains(m.uid)).toList();
  
  // Filter out current user from selected members
  final filteredSelectedMembers = selectedMembers.where((m) => m.uid != currentUser?.uid).toList();
  
  if (filteredSelectedMembers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You cannot perform actions on yourself'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  switch (action) {
    case 'make_admin':
      _showBulkMakeAdminConfirmation(filteredSelectedMembers);
      break;
    case 'remove_admin':
      _showBulkRemoveAdminConfirmation(filteredSelectedMembers);
      break;
    case 'unapprove':
      _showBulkUnapproveConfirmation(filteredSelectedMembers);
      break;
    case 'remove':
      _showBulkRemoveConfirmation(filteredSelectedMembers);
      break;
  }
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
  final isCurrentUser = currentUser?.uid == member.uid;
  final isSelected = _selectedMemberIds.contains(member.uid);
  final isAdmin = currentUser?.isAdmin == true;
  final hasPhoneNumber = member.phoneNumber != null && member.phoneNumber!.isNotEmpty;
  
  // Pre-calculate contact info
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
            if (_isSelectionMode && isAdmin && !isCurrentUser) {
              setState(() {
                _toggleMemberSelection(member.uid, isCurrentUser);
              });
            } else {
              _navigateToMemberDetails(member);
            }
          },
          onLongPress: isAdmin && !isCurrentUser ? () {
            setState(() {
              if (!_isSelectionMode) {
                _isSelectionMode = true;
              }
              _toggleMemberSelection(member.uid, isCurrentUser);
            });
          } : null,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // Avatar container with consistent size
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
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
                      
                      // Selection overlay (doesn't affect layout)
                     if (_isSelectionMode && isAdmin && !isCurrentUser)
  Positioned(
    right: -4,
    top: -4,
    child: GestureDetector(
      onTap: () {
        setState(() {
          _toggleMemberSelection(member.uid, isCurrentUser);
        });
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
                
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(width: 8),
                          if (isCurrentUser)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (member.isAdmin && !isCurrentUser) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
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
                
                // Action buttons area - maintains consistent width
                SizedBox(
  width: 48, // 🔒 fixed width prevents overflow
  child: Align(
    alignment: Alignment.centerRight,
    child: (!_isSelectionMode && hasPhoneNumber)
        ? InkResponse(
            radius: 20,
            onTap: () {
              _makePhoneCall(member.phoneNumber!);
            },
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
      
      // Horizontal divider
      Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border(context),
      ),
    ],
  );
}
// Helper method to make phone call

Future<void> _makePhoneCall(String phoneNumber) async {
  try {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanedNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number: $phoneNumber'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Use 'telprompt:' for iOS or 'tel:' for both platforms
    final url = Uri.parse('tel:$cleanedNumber');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback for web/unsupported platforms
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot make calls from this device'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
  
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}