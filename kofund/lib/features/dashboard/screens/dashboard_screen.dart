// lib/features/community/screens/dashboard_screen.dart
import 'package:kofund/core/skeleton/stats_card_skeleton.dart';
import 'package:kofund/core/skeleton/program_card_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/features/auth/models/user_model.dart';
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
import 'dart:ui' as dart_ui;
import 'package:kofund/features/community/providers/community_provider.dart';
import 'package:kofund/features/dashboard/widgets/invite_members_dialog.dart';
import 'package:kofund/core/skeleton/members_skeleton.dart';
import 'package:kofund/core/services/storage_service.dart';

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
  
  // 🆕 Greeting functionality
  bool _showGreeting = true;
  double _greetingOpacity = 1.0;

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

  Widget _buildCommunityAvatar(BuildContext context, Map<String, dynamic> stats, String? cid, bool isAdmin, UserModel? user, {double size = 46}) {
    final String? logoUrl = stats['clubLogo'];
    final String clubName = (stats['clubName'] != null && stats['clubName'].toString().trim().isNotEmpty)
        ? stats['clubName']
        : (user?.communityName ?? 'Community');
    final String initial = clubName.isNotEmpty ? clubName[0].toUpperCase() : 'C';

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitialPlaceholder(initial, size),
              ),
            )
          : _buildInitialPlaceholder(initial, size),
    );

    return avatar;
  }

  Widget _buildInitialPlaceholder(String initial, double size) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getGreetingText(String? name) {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour < 12) {
      timeGreeting = "Morning";
    } else if (hour < 17) {
      timeGreeting = "Afternoon";
    } else {
      timeGreeting = "Evening";
    }
    
    final displayName = (name != null && name.isNotEmpty) ? name.split(' ').first : 'there';
    return "Good $timeGreeting, $displayName!";
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
        StorageService(),
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
            _buildDashboardSliverAppBar(stats, isDarkMode, cid, user),
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

  Widget _buildDashboardSliverAppBar(Map<String, dynamic> stats, bool isDarkMode, String? cid, UserModel? user) {
    final bool isAdmin = user?.isAdmin ?? false;
    
    return SliverAppBar(
      expandedHeight:280,
      toolbarHeight: 90,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: _buildNotificationIconButton(context),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double topPadding = MediaQuery.of(context).padding.top;
          final double collapsedHeight = 90 + topPadding + 28;
          final double expandedHeight = 280.0;
          
          final double expandRatio = ((constraints.maxHeight - collapsedHeight) / 
              (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

          final double expandedOpacity = (expandRatio * 2 - 1).clamp(0.0, 1.0);
          
          // Math for smooth Avatar sliding and scaling (EXACT Profile Screen Constants)
          final double currentAvatarSize = dart_ui.lerpDouble(60.0, 96.0, expandRatio)!;
          final double currentAvatarX = dart_ui.lerpDouble(20.0, (constraints.maxWidth - currentAvatarSize) / 2, expandRatio)!;
          final double currentAvatarY = dart_ui.lerpDouble(topPadding + 15.0, topPadding + 40.0, expandRatio)!;
          
          // Math for smooth Swarm translating and scaling (EXACT Profile Screen Curve)
          final double arcOffset = (1 - (2 * expandRatio - 1).abs()); 
          final double dodgeAmount = 20.0 * (arcOffset > 0 ? arcOffset : 0); 
          
          final double currentNameTop = dart_ui.lerpDouble(26.0 + topPadding, 155.0 + topPadding, expandRatio)! + dodgeAmount;
          final double currentMembersTop = dart_ui.lerpDouble(50.0 + topPadding, 185.0 + topPadding, expandRatio)! + dodgeAmount;
          final double currentBadgeTop = dart_ui.lerpDouble(80.0 + topPadding, 212.0 + topPadding, expandRatio)! + dodgeAmount;
          
          final double currentLeftPadding = dart_ui.lerpDouble(90.0, 0.0, expandRatio)!;
          final double currentRightPadding = dart_ui.lerpDouble(70.0, 0.0, expandRatio)!;
          final double currentAlignmentX = dart_ui.lerpDouble(-1.0, 0.0, expandRatio)!;

          return Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient(context),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Sliding & Scaling Avatar (Always Visible)
                Positioned(
                  left: currentAvatarX,
                  top: currentAvatarY,
                  child: _buildCommunityAvatar(
                    context, 
                    stats, 
                    cid, 
                    isAdmin, 
                    user,
                    size: currentAvatarSize,
                  ),
                ),

                // 2. SWARMING CLUB NAME
                Positioned(
                  top: currentNameTop,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(left: currentLeftPadding, right: currentRightPadding),
                    child: Align(
                      alignment: Alignment(currentAlignmentX, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              (stats['clubName'] != null && stats['clubName'].toString().trim().isNotEmpty)
                                  ? stats['clubName']
                                  : (user?.communityName ?? ""),
                              style: TextStyle(
                                fontSize: dart_ui.lerpDouble(18.0, 26.0, expandRatio)!,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _navigateToEditCommunity,
                              child: Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. SWARMING MEMBERS
                Positioned(
                  top: currentMembersTop,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(left: currentLeftPadding, right: currentRightPadding),
                    child: Align(
                      alignment: Alignment(currentAlignmentX, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: dart_ui.lerpDouble(12.0, 14.0, expandRatio)!,
                            color: Colors.white.withValues(alpha: dart_ui.lerpDouble(0.7, 0.8, expandRatio)!),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${stats['membersCount'] ?? 0} Members",
                            style: TextStyle(
                              fontSize: dart_ui.lerpDouble(12.0, 14.0, expandRatio)!,
                              color: Colors.white.withValues(alpha: dart_ui.lerpDouble(0.7, 0.8, expandRatio)!),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. GREETING OVERLAY (Centered in expanded state)
                if (expandedOpacity > 0 && _showGreeting)
                  Positioned(
                    top: currentBadgeTop,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: expandedOpacity * _greetingOpacity,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            _getGreetingText(user?.displayName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(28),
        child: Container(
          height: 28,
          width: double.infinity,
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
