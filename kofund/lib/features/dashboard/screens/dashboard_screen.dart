// lib/features/community/screens/dashboard_screen.dart
import 'package:kofund/core/skeleton/dashboard_skeleton.dart';
import 'package:kofund/core/skeleton/stats_card_skeleton.dart';
import 'package:kofund/core/skeleton/program_card_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clipboard/clipboard.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/members_widget.dart';
import '../widgets/history_widget.dart';
import '../widgets/pending_requests_widget.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';
import '../../../features/programs/providers/program_provider.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/programs/models/program_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/dashboard/widgets/program_carousel_widget.dart';
import 'package:kofund/features/polls/widgets/poll_dashboard_widget.dart';
import 'package:kofund/features/notifications/widgets/notification_badge.dart';
import 'package:kofund/features/programs/screens/program_details_screen.dart';
import 'dart:ui';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/core/constants/notification_types.dart';

// ADD THESE IMPORTS
import 'package:kofund/features/history/providers/history_provider.dart';
import 'package:kofund/features/members/providers/member_provider.dart';
import 'package:kofund/features/polls/providers/poll_provider.dart';
import 'package:kofund/core/services/contribution_service.dart';
import 'package:kofund/core/services/expense_service.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/program_service.dart';
import 'package:kofund/core/services/virtual_user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/core/services/community_firestore_service.dart';

// 🆕 ADD INVITE IMPORTS
import 'package:kofund/features/community/providers/community_provider.dart';
import 'package:kofund/features/dashboard/widgets/invite_members_dialog.dart';

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
  final RefreshController _refreshController = RefreshController();
  
  // Track previous user/community to detect changes
  String? _previousUserId;
  String? _previousCommunityId;
  
  // 🆕 Invite functionality fields
  bool _isAdmin = false;
  bool _canInvite = false;
  String _inviteCode = '';
  String _inviteLink = '';
  bool _inviteLoading = false;

void _onRefresh() async {
  print('🔄 DEBUG: Pull to refresh triggered in Dashboard');
  
  try {
    final user = context.read<AppAuthProvider>().user;
    final cid = user?.communityId;
    
    if (cid != null && cid.isNotEmpty && user != null) {
      await context.read<DashboardProvider>().refreshDashboard(cid);
      await context.read<ProgramProvider>().loadCommunityPrograms(cid);
      await context.read<ProgramProvider>().loadMyParticipations(user.uid, cid);
      
      // ✅ RESET PROVIDERS FOR FRESH DATA
      _resetWidgetProviders(user.uid, cid);
      
      // ✅ REFRESH USER PROVIDER FOR PENDING REQUESTS
      await context.read<UserProvider>().loadCommunityMembers(cid);
      
      // 🆕 Refresh invite info
      await _refreshInviteInfo(cid, user.uid);
    }
    
    _refreshController.refreshCompleted();
    print('✅ DEBUG: Dashboard refresh completed successfully');
  } catch (e) {
    _refreshController.refreshFailed();
    print('❌ DEBUG: Dashboard refresh failed: $e');
  }
}

void _resetWidgetProviders(String userId, String communityId) {
  print('🔄 DEBUG: Resetting widget providers for user $userId, community $communityId');
  
  try {
    // Reset MemberProvider
    final memberProvider = context.read<MemberProvider>();
    memberProvider.clearDataForUserChange();
    memberProvider.refreshForUser(communityId);
    
    // Reset HistoryProvider
    final historyProvider = context.read<HistoryProvider>();
    historyProvider.clearDataForUserChange();
    historyProvider.setUserCommunity(communityId);
    
    // ✅ RESET USER PROVIDER
    final userProvider = context.read<UserProvider>();
    userProvider.clearData();
    
    print('✅ DEBUG: Widget providers reset successfully');
  } catch (e) {
    print('❌ DEBUG: Error resetting widget providers: $e');
  }
}

  @override
  void dispose() {
    _refreshController.dispose();
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
      print('👤 DEBUG: User/Community changed in DashboardScreen');
      print('   Previous user: $_previousUserId, community: $_previousCommunityId');
      print('   New user: $currentUserId, community: $currentCommunityId');
      
      _previousUserId = currentUserId;
      _previousCommunityId = currentCommunityId;
      
      // Reset dashboard state for new user
      _resetDashboardForNewUser();
    }
  }

  void _resetDashboardForNewUser() {
    print('🔄 DEBUG: Resetting dashboard for new user/community');
    
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
      
      // Reset HistoryProvider
      final historyProvider = context.read<HistoryProvider>();
      historyProvider.clearDataForUserChange();
      
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
        print('🔄 DEBUG: Initializing dashboard data for community: $communityId');
        
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
        print('⚠️ DEBUG: No community ID found for user');
      }
      
      _isInitializing = false;
    });
  }

void _initializeWidgetProviders(String userId, String communityId) {
  print('🔄 DEBUG: Initializing widget providers');
  
  try {
    // Initialize HistoryProvider
    final historyProvider = context.read<HistoryProvider>();
    historyProvider.setUserCommunity(communityId);
    
    // Initialize MemberProvider
    final memberProvider = context.read<MemberProvider>();
    memberProvider.refreshForUser(communityId);
    
    // ✅ INITIALIZE USER PROVIDER
    final userProvider = context.read<UserProvider>();
    userProvider.loadCommunityMembers(communityId);
    
    print('✅ DEBUG: Widget providers initialized successfully');
  } catch (e) {
    print('❌ DEBUG: Error initializing widget providers: $e');
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
      print('❌ Error checking admin permissions: $e');
    }
  }

  // 🆕 Load invite information
  Future<void> _loadInviteInfo(String communityId) async {
    try {
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
        await communityProvider.checkInvitePermission(communityId);
        _canInvite = communityProvider.canInvite;
        
        setState(() {});
      }
    } catch (e) {
      print('❌ Error loading invite info: $e');
    }
  }

  // 🆕 Refresh invite information
  Future<void> _refreshInviteInfo(String communityId, String userId) async {
    try {
      if (_isAdmin) {
        await _loadInviteInfo(communityId);
      }
    } catch (e) {
      print('❌ Error refreshing invite info: $e');
    }
  }

  // 🆕 Show invite dialog
  void _showInviteDialog() async {
    final user = context.read<AppAuthProvider>().user;
    final cid = user?.communityId;
    
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
      create: (_) => HistoryProvider(
        contributionService: ContributionService(),
        expenseService: ExpenseService(),
        programService: ProgramService(),
        userService: UserService(),
        authProvider: auth,
      ),
    ),
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
          if (provider.isLoading && !_hasLoadedData) {
            return DashboardSkeleton(isDarkMode: isDarkMode);
          }

          if (provider.errorMessage.isNotEmpty) {
            return _buildErrorState(provider, isDarkMode, cid!);
          }

          final stats = provider.getDashboardStats();

          return Scaffold(
            backgroundColor: AppColors.background(context),
            body: Stack(
              children: [
                Column(
                  children: [
                    // 🔒 FIXED APP BAR - SIMPLE STYLE
                    _buildFixedAppBar(stats, isDarkMode),
                    
                    // 🔄 REFRESHABLE AREA STARTS FROM STATS CARD
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
                          refreshingText: 'Refreshing dashboard...',
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
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12.0),
                          children: [
                            const SizedBox(height: 8),
                            _buildStatsCard(stats, isDarkMode),
                            const SizedBox(height: 16),
                         
                            
                            ProgramCarouselWidget(
                              // communityId: cid!,
                              isAdmin: user?.isAdmin ?? false,
                            ),
                                                        const SizedBox(height: 16),

                            //    PollDashboardWidget(
                            //   communityId: cid!,
                            //   isAdmin: user?.isAdmin ?? false,
                            // ),
                            // const SizedBox(height: 24),
                      //    if (user?.isAdmin ?? false) ...[
                      //   PendingRequestsWidget(),
                      // ],
                      
                      // const SizedBox(height: 24),
                            MembersWidget(key: ValueKey('members-$userId-$cid')),
                            const SizedBox(height: 16),
                            HistoryWidget(key: ValueKey('history-$userId-$cid')),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // 🆕 ADD INVITE FLOATING ACTION BUTTON
                if (!_inviteLoading)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      onPressed: _showInviteDialog,
                      child: const Icon(Icons.share),
                      tooltip: 'Invite Members',
                      heroTag: 'invite_members',
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                    ),
                  ),
                
                // 🆕 SHOW LOADING INDICATOR WHEN INVITE LOADING
                if (_inviteLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

// 🔒 FIXED APP BAR – MODERN GRADIENT + GLASS ACTION
// 🔒 FIXED APP BAR – MODERN GRADIENT + GLASS ACTION
Widget _buildFixedAppBar(Map<String, dynamic> stats, bool isDarkMode) {
  final auth = Provider.of<AppAuthProvider>(context, listen: false);
  final isAdmin = auth.user?.isAdmin ?? false;
  
  return Container(
    height: 150, // ⬅ Reduced to avoid overflow
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: SafeArea(
      bottom: false, // ⬅ CRITICAL to fix overflow
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // LEFT CONTENT
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CLUB NAME + INLINE EDIT (LIKE HTML SPAN)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          stats['clubName'] ?? "Your Club Name",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      if (_isAdmin) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _navigateToEditCommunity,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 0),

                  // MEMBERS COUNT CHIP
                  Container(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${stats['membersCount'] ?? 0} Members",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // RIGHT ACTION – GLASS NOTIFICATION (COMMENTED OUT)
            // ClipRRect(
            //   borderRadius: BorderRadius.circular(30),
            //   child: BackdropFilter(
            //     filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            //     child: Container(
            //       width: 56,
            //       height: 56,
            //       decoration: BoxDecoration(
            //         color: Colors.white.withOpacity(0.18),
            //         borderRadius: BorderRadius.circular(30),
            //         border: Border.all(
            //           color: Colors.white.withOpacity(0.35),
            //           width: 1.2,
            //         ),
            //       ),
            //       child: const Center(
            //         child: NotificationBadge(
            //           iconSize: 22,
            //           badgeColor: Colors.redAccent,
            //           textColor: Colors.white,
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
            
            // NEW: ADMIN PENDING REQUESTS ICON (SHOWS ONLY FOR ADMINS)
            if (isAdmin) ...[
              Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final pendingCount = userProvider.pendingMembers.length;
                  
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to approval requests screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ApprovalRequestsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Main icon
                              Icon(
                                Icons.person_add_alt_1,
                                color: Colors.white,
                                size: 24,
                              ),
                              
                              // Badge for pending count
                              if (pendingCount > 0)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.warning(context),
                                      shape: BoxShape.circle,
                                    
                                    ),
                                    child: Center(
                                      child: Text(
                                        pendingCount > 9 ? '9+' : pendingCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              // For non-admin users, you can show notification icon or nothing
              // Here I'm keeping it empty, but you can uncomment notification icon below:
              
              // NOTIFICATION ICON FOR NON-ADMINS (OPTIONAL - UNCOMMENT IF NEEDED)
              /*
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1.2,
                      ),
                    ),
                    child: const Center(
                      child: NotificationBadge(
                        iconSize: 22,
                        badgeColor: Colors.redAccent,
                        textColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              */
            ],
          ],
        ),
      ),
    ),
  );
}


  // ================================================================
  // COMMUNITY NOT FOUND
  // ================================================================
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
  // ERROR UI
  // ================================================================
  Widget _buildErrorState(
      DashboardProvider provider, bool isDarkMode, String cid) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDarkMode ? AppColors.darkError : AppColors.lightError,
          ),
          const SizedBox(height: 16),
          Text(
            provider.errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? AppColors.darkError : AppColors.lightError,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.refreshDashboard(cid),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
              foregroundColor: isDarkMode ? Colors.black : Colors.white,
            ),
            child: const Text("Retry"),
          )
        ],
      ),
    );
  }

  // STATS CARD - GRADIENT STYLE (BELOW APP BAR)
  // ================================================================
  Widget _buildStatsCard(Map<String, dynamic> stats, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.05),
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