// lib/features/community/screens/dashboard_screen.dart
import 'package:kofund/core/skeleton/stats_card_skeleton.dart';
import 'package:kofund/core/skeleton/program_card_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:clipboard/clipboard.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/members_widget.dart';

import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';
import 'package:kofund/core/widgets/admin_assistant_toast.dart';
import '../../../features/programs/providers/program_provider.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/dashboard/widgets/program_carousel_widget.dart';
import 'package:kofund/features/polls/providers/poll_provider.dart';
import 'package:kofund/core/services/contribution_service.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/virtual_user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/core/services/community_firestore_service.dart';
import 'package:kofund/features/community/providers/community_provider.dart';
import 'package:kofund/features/dashboard/widgets/invite_members_dialog.dart';
import 'package:kofund/core/skeleton/members_skeleton.dart';

// ADD THESE IMPORTS
import 'package:badges/badges.dart' as badges;
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/members/providers/member_provider.dart';

// 🆕 ADD INVITE IMPORTS

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMembers;
  
  const DashboardScreen({super.key, this.onNavigateToMembers});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? communityId;
  bool _hasLoadedData = false;
  bool _isInitializing = false;
  bool _isManualRefreshing = false;
  
  // Track previous user/community to detect changes
  String? _previousUserId;
  String? _previousCommunityId;
  
  // 🆕 Invite functionality fields
  bool _isAdmin = false;
  bool _canInvite = false;
  String _inviteCode = '';
  String _inviteLink = '';
  bool _inviteLoading = false;
  bool _hasShownAdminToast = false;

Future<void> _onRefresh() async {
  HapticHelper.light();
  debugPrint('🔄 DEBUG: Pull to refresh triggered in Dashboard');
  if (_isManualRefreshing) return;

  setState(() {
    _isManualRefreshing = true;
  });
  
  try {
    final user = context.read<AppAuthProvider>().user;
    final cid = user?.communityId;
    
    if (cid != null && cid.isNotEmpty && user != null) {
      // Refresh all related providers
      await Future.wait([
        context.read<DashboardProvider>().refreshDashboard(cid),
        context.read<ProgramProvider>().loadCommunityPrograms(cid),
        context.read<ProgramProvider>().loadMyParticipations(user.uid, cid),
        context.read<UserProvider>().loadCommunityMembers(cid),
        _loadInviteInfo(cid),
      ]);
      if (!mounted) return;
      
      // Reset MemberProvider separately
      final memberProvider = context.read<MemberProvider>();
      memberProvider.clearDataForUserChange();
      memberProvider.refreshForUser(cid);
    }
    debugPrint('✅ DEBUG: Dashboard refresh completed successfully');
  } catch (e) {
    debugPrint('❌ DEBUG: Dashboard refresh failed: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isManualRefreshing = false;
        _hasLoadedData = true;
      });
    }
  }
}

void _resetWidgetProviders(String userId, String communityId) {
  debugPrint('🔄 DEBUG: Resetting widget providers for user $userId, community $communityId');
  
  try {
    // Reset MemberProvider
    final memberProvider = context.read<MemberProvider>();
    memberProvider.clearDataForUserChange();
    memberProvider.refreshForUser(communityId);
    

    
    // ✅ RESET USER PROVIDER
    final userProvider = context.read<UserProvider>();
    userProvider.clearData();
    
    debugPrint('✅ DEBUG: Widget providers reset successfully');
  } catch (e) {
    debugPrint('❌ DEBUG: Error resetting widget providers: $e');
  }
}

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Listen for auth changes
    final user = context.read<AppAuthProvider>().user;
    final currentUserId = user?.uid;
    final currentCommunityId = user?.communityId;
    
    // Check if user or community has changed
    if (currentUserId != _previousUserId || currentCommunityId != _previousCommunityId) {
      debugPrint('👤 DEBUG: User/Community changed in DashboardScreen');
      debugPrint('   Previous user: $_previousUserId, community: $_previousCommunityId');
      debugPrint('   New user: $currentUserId, community: $currentCommunityId');
      
      _previousUserId = currentUserId;
      _previousCommunityId = currentCommunityId;
      
      // Reset dashboard state for new user
      _resetDashboardForNewUser();
    }
  }

  void _resetDashboardForNewUser() {
    debugPrint('🔄 DEBUG: Resetting dashboard for new user/community');
    
    if (mounted) {
      setState(() {
        _hasLoadedData = false;
        _isInitializing = false;
        _isAdmin = false;
        _canInvite = false;
        _inviteCode = '';
        _inviteLink = '';
      });
    }
    
    // Reset providers when user/community changes
    final user = context.read<AppAuthProvider>().user;
    final cid = user?.communityId;
    
    if (cid != null && cid.isNotEmpty && user != null) {
      // Reset MemberProvider
      final memberProvider = context.read<MemberProvider>();
      memberProvider.clearDataForUserChange();
      

      
      // Load fresh data
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    if (_isInitializing || _hasLoadedData) return;
    
    _isInitializing = true;
    
    Future.microtask(() {
      final user = context.read<AppAuthProvider>().user;
      communityId = user?.communityId;

      if (communityId != null && communityId!.isNotEmpty && user != null) {
        debugPrint('🔄 DEBUG: Initializing dashboard data for community: $communityId');
        
        // ✅ Load dashboard data
        context.read<DashboardProvider>().loadDashboardData(communityId!);
        
        // ✅ Load programs data  
        context.read<ProgramProvider>().loadCommunityPrograms(communityId!);
        
        // ✅ CRITICAL: Load user participations
        context.read<ProgramProvider>().loadMyParticipations(user.uid, communityId!);
        
        // ✅ Set up participation listener
        context.read<ProgramProvider>().watchUserParticipation(communityId!, user.uid);
        
        // ✅ Initialize widget providers
        _initializeWidgetProviders(user.uid, communityId!);
        
        // 🆕 Check admin permissions and load invite info
        _checkAdminPermissions(user.uid, communityId!);
        
        _hasLoadedData = true;
      } else {
        debugPrint('⚠️ DEBUG: No community ID found for user');
      }
      
      _isInitializing = false;
    });
  }

void _initializeWidgetProviders(String userId, String communityId) {
  debugPrint('🔄 DEBUG: Initializing widget providers');
  
  try {

    
    // Initialize MemberProvider
    final memberProvider = context.read<MemberProvider>();
    memberProvider.refreshForUser(communityId);
    
    // ✅ INITIALIZE USER PROVIDER
    final userProvider = context.read<UserProvider>();
    userProvider.loadCommunityMembers(communityId);
    
    debugPrint('✅ DEBUG: Widget providers initialized successfully');
  } catch (e) {
    debugPrint('❌ DEBUG: Error initializing widget providers: $e');
  }
}

  // 🆕 Check admin permissions and load invite info
  void _checkAdminPermissions(String userId, String communityId) async {
    try {
      final communityProvider = context.read<CommunityProvider>();
      final user = context.read<AppAuthProvider>().user;
      
      // Check if user is admin from user data
      _isAdmin = user?.isAdmin ?? false;
      
      // Get invite info if admin
      if (_isAdmin && communityId.isNotEmpty) {
        await _loadInviteInfo(communityId);
      }
      
      setState(() {});
    } catch (e) {
      debugPrint('❌ Error checking admin permissions: $e');
    }
  }

  // 🆕 Load invite information
  Future<void> _loadInviteInfo(String communityId) async {
    try {
      final authProvider = context.read<AppAuthProvider>();
      final user = authProvider.user;
      final userProvider = context.read<UserProvider>();
      final communityProvider = context.read<CommunityProvider>();
      
      // Load current community to get invite info
      await communityProvider.loadCurrentCommunity(communityId);
      
      // Get invite code and link
      final community = communityProvider.currentCommunity;
      if (community != null) {
        _inviteCode = community.inviteCode;
        _inviteLink = community.inviteLink ?? '';
        
        // If no invite link, generate one
        if (_inviteLink.isEmpty) {
          _inviteLink = await communityProvider.getInviteLink(communityId);
        }
        
        // Check invite permissions
        if (!mounted) return;
        _canInvite = communityProvider.canInvite;
        
        setState(() {});
      }
      // ✅ Trigger Admin Assistant Toast if needed
      if (!_hasShownAdminToast && (user?.isAdmin ?? false)) {
        final pendingCount = userProvider.pendingMembers.length;
        if (pendingCount > 0) {
          _hasShownAdminToast = true;
          // Small delay to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              AdminAssistantToast.show(
                context, 
                pendingCount,
                onAction: _navigateToApprovalScreen,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading invite info: $e');
    }
  }

  // 🆕 Refresh invite information
  Future<void> _refreshInviteInfo(String communityId, String userId) async {
    try {
      if (_isAdmin) {
        await _loadInviteInfo(communityId);
      }
    } catch (e) {
      debugPrint('❌ Error refreshing invite info: $e');
    }
  }

  // 🆕 Show invite dialog
  void _showInviteDialog() async {
    final user = context.read<AppAuthProvider>().user;
    final cid = user?.communityId;
    if (!mounted) return;
    
    if (cid == null || cid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No community found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    

    
    setState(() {
      _inviteLoading = true;
    });
    
    try {
      final communityProvider = context.read<CommunityProvider>();
      final dashboardProvider = context.read<DashboardProvider>();
      
      // Ensure we have the latest invite info
      if (_inviteCode.isEmpty || _inviteLink.isEmpty) {
        await _loadInviteInfo(cid);
      }
      
      if (!mounted) return;
      
      // Get community name from dashboard stats
      final stats = dashboardProvider.getDashboardStats();
      final communityName = stats['clubName'] ?? user?.communityName ?? 'Community';
      
      // Show invite dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => InviteMembersDialog(
          communityId: cid,
          communityName: communityName,
          inviteCode: _inviteCode,
          inviteLink: _inviteLink,
      
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _inviteLoading = false;
      });
    }
  }


  // 🆕 Copy invite code to clipboard
  void _copyInviteCode() async {
    if (_inviteCode.isEmpty) return;
    
    await FlutterClipboard.copy(_inviteCode);
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🆕 Copy invite link to clipboard
  void _copyInviteLink() async {
    if (_inviteLink.isEmpty) return;
    
    await FlutterClipboard.copy(_inviteLink);
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🆕 Navigate to edit community screen
  void _navigateToEditCommunity() {
    Navigator.pushNamed(context, RouteNames.editCommunity);
  }

  // 🆕 BUILD THE APPROVALS FAB
  Widget _buildApprovalsFab(BuildContext context, int count) {
    return FloatingActionButton.small(
      heroTag: 'approvals_fab',
      onPressed: _navigateToApprovalScreen,
      backgroundColor: AppColors.error(context),
      elevation: 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Text(
                count > 9 ? '9+' : count.toString(),
                style: TextStyle(
                  color: AppColors.error(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 NAVIGATE TO APPROVAL SCREEN
  void _navigateToApprovalScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ApprovalRequestsScreen(),
      ),
    );
  }

  Widget _buildNotificationIconButton(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              onTap: () {
                HapticHelper.light();
                Navigator.pushNamed(context, RouteNames.notifications);
              },
              child: Center(
                child: badges.Badge(
                  showBadge: provider.unreadCount > 0,
                  badgeContent: Text(
                    provider.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.error(context),
                    padding: const EdgeInsets.all(4),
                    elevation: 0,
                  ),
                  position: badges.BadgePosition.topEnd(top: -6, end: -6),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final auth = Provider.of<AppAuthProvider>(context);
    final user = auth.user;
    final cid = user?.communityId;
    final userId = user?.uid ?? 'no-user';

    if (cid == null || cid.isEmpty) {
      return _buildNoCommunity(isDarkMode);
    }

   return MultiProvider(
  providers: [

    ChangeNotifierProvider(
      create: (_) => MemberProvider(
        userService: UserService(),
        authProvider: auth,
        participantService: ParticipantService(),
        contributionService: ContributionService(),
         virtualUserService: VirtualUserService(), // Add this
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => CommunityProvider(
        CommunityFirestoreService(),
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => PollProvider(),
    ),
    // ✅ FIXED: Pass UserService parameter
    ChangeNotifierProvider(
      create: (_) => UserProvider(
        UserService(), // Add this
      ),
    ),
  ],
      child: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          final bool isRefreshing = provider.isLoading || _isManualRefreshing;
          final bool showSkeleton = isRefreshing && !_hasLoadedData;
          final stats = provider.getDashboardStats();

          return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            _buildDashboardSliverAppBar(stats, isDarkMode),
          ];
        },
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: _onRefresh,
            ),
            
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppDimensions.screenPaddingHorizontal),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: AppDimensions.spaceSmall),
                  
                  if (showSkeleton) ...[
                    StatsCardSkeleton(isDarkMode: isDarkMode),
                    const SizedBox(height: 24),
                    ProgramCardSkeleton(isDarkMode: isDarkMode),
                    const SizedBox(height: 24),
                    MembersSkeleton(isDarkMode: isDarkMode),
                  ] else ...[
                    _buildStatsCard(stats, isDarkMode),
                    const SizedBox(height: AppDimensions.spaceMedium),
                    
                    ProgramCarouselWidget(
                      isAdmin: user?.isAdmin ?? false,
                      key: ValueKey('programs-$userId-$cid-${_isManualRefreshing ? "ref" : "stable"}'),
                    ),
                    const SizedBox(height: 16),
                    
                    MembersWidget(
                      key: ValueKey('members-$userId-$cid-${_isManualRefreshing ? "ref" : "stable"}'),
                    ),
                  ],
                  
                  const SizedBox(height: 100),
                ]),
              ),
              ),
            ],
          ),
      ),
      // FABs moved into Stack if needed, but Scaffold has built-in FAB slot
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_inviteLoading && (user?.isAdmin ?? false))
             Consumer<UserProvider>(
               builder: (context, userProvider, child) {
                 final pendingCount = userProvider.pendingMembers.length;
                 if (pendingCount == 0) return const SizedBox.shrink();
                 return Padding(
                   padding: const EdgeInsets.only(bottom: 16),
                   child: _buildApprovalsFab(context, pendingCount),
                 );
               },
             ),
          if (!_inviteLoading)
            FloatingActionButton(
              onPressed: _showInviteDialog,
              tooltip: 'Invite Members',
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              child: const Icon(Icons.share),
            ),
        ],
      ),
    );
        },
      ),
    );
  }

  Widget _buildDashboardSliverAppBar(Map<String, dynamic> stats, bool isDarkMode) {
    return SliverAppBar(
      expandedHeight: 160,
      toolbarHeight: 100,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          final double statusBarHeight = MediaQuery.paddingOf(context).top;
          final double progress = ((top - (100 + statusBarHeight)) / (160 - 100)).clamp(0.0, 1.0);
          final double fontSize = 18 + (12 * progress);
          
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient(context),
                ),
              ),
              // REMOVED Positioned notification icon - moved into FlexibleSpaceBar Row
              FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
              ),
              // ✅ MANUAL HEADER: Moving outside FlexibleSpaceBar to avoid auto-scaling of icons
              Positioned(
                left: 20,
                right: 16,
                bottom: 24 + (18 * progress),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  stats['clubName'] ?? "Your Club Name",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5 - (0.5 * progress),
                                  ),
                                ),
                              ),
                              if (_isAdmin && progress > 0.5) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: _navigateToEditCommunity,
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 20 * progress,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // 🔔 FIXED SIZE: This will NOT scale with the AppBar
                        _buildNotificationIconButton(context),
                      ],
                    ),
                    Opacity(
                      opacity: 0.7 + (0.3 * (1.0 - progress)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 13 + (3 * progress),
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${stats['membersCount'] ?? 0} Members",
                            style: TextStyle(
                              fontSize: 12 + (2 * progress),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(28),
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppDimensions.radiusExtraLarge),
              topRight: Radius.circular(AppDimensions.radiusExtraLarge),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoCommunity(bool isDarkMode) {
    return Center(
      child: Text(
        "Community not found",
        style: TextStyle(
          color: isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          fontSize: 16,
        ),
      ),
    );
  }
  // ================================================================
  Widget _buildStatsCard(Map<String, dynamic> stats, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: 1,
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monthly Program Balance",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            "₹${(stats['monthlyBalance'] ?? 0.0).toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                "Collected",
                "₹${(stats['monthlyCollected'] ?? 0.0).toStringAsFixed(2)}",
              ),
              _buildStatItem(
                "Expenses", 
                "₹${(stats['monthlyExpenses'] ?? 0.0).toStringAsFixed(2)}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

