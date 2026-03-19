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

import '../widgets/pending_requests_widget.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';
import 'package:kofund/core/widgets/admin_assistant_toast.dart';
import '../../../features/programs/providers/program_provider.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:kofund/features/programs/models/program_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/dashboard/widgets/program_carousel_widget.dart';
import 'package:kofund/features/polls/widgets/poll_dashboard_widget.dart';
import 'dart:ui';
import 'package:kofund/core/widgets/glass_action_button.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/core/constants/notification_types.dart';

// ADD THESE IMPORTS

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
import 'package:flutter/foundation.dart' show debugPrint;

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
  bool _hasShownAdminToast = false;

void _onRefresh() async {
  debugPrint('🔄 DEBUG: Pull to refresh triggered in Dashboard');
  
  try {
    final user = context.read<AppAuthProvider>().user;
    final cid = user?.communityId;
    
    if (cid != null && cid.isNotEmpty && user != null) {
      await context.read<DashboardProvider>().refreshDashboard(cid);
      if (!mounted) return;
      await context.read<ProgramProvider>().loadCommunityPrograms(cid);
      if (!mounted) return;
      await context.read<ProgramProvider>().loadMyParticipations(user.uid, cid);
      
      // ✅ RESET PROVIDERS FOR FRESH DATA
      _resetWidgetProviders(user.uid, cid);
      
      // ✅ REFRESH USER PROVIDER FOR PENDING REQUESTS
      await context.read<UserProvider>().loadCommunityMembers(cid);
      
      // 🆕 Refresh invite info
      await _refreshInviteInfo(cid, user.uid);
    }
    
    _refreshController.refreshCompleted();
    debugPrint('✅ DEBUG: Dashboard refresh completed successfully');
  } catch (e) {
    _refreshController.refreshFailed();
    debugPrint('❌ DEBUG: Dashboard refresh failed: $e');
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
        await communityProvider.checkInvitePermission(communityId);
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
                borderRadius: BorderRadius.circular(10),
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
                          padding: AppStyles.screenPadding / 1.5,
                          children: [
                            const SizedBox(height: AppDimensions.spaceSmall),
                            _buildStatsCard(stats, isDarkMode),
                            const SizedBox(height: AppDimensions.spaceMedium),
                         
                            
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
                            if (user?.isAdmin ?? false) ...[
                              // Removed static widget, now using FAB
                            ],
                            MembersWidget(key: ValueKey('members-$userId-$cid')),
                            const SizedBox(height: 16),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // 🆕 ADD ADMIN APPROVALS FAB
                if (!_inviteLoading && (user?.isAdmin ?? false))
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      final pendingCount = userProvider.pendingMembers.length;
                      if (pendingCount == 0) return const SizedBox.shrink();
                      
                      return Positioned(
                        bottom: 90, // Positioned above the share button
                        right: 20,
                        child: _buildApprovalsFab(context, pendingCount),
                      );
                    },
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
                      color: Colors.black.withValues(alpha: 0.3),
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
        bottomLeft: Radius.circular(AppDimensions.radiusExtraLarge),
        bottomRight: Radius.circular(AppDimensions.radiusExtraLarge),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
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
                            padding: const EdgeInsets.all(AppDimensions.spaceExtraSmall),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.85),
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
            //         color: Colors.white.withValues(alpha: 0.18),
            //         borderRadius: BorderRadius.circular(30),
            //         border: Border.all(
            //           color: Colors.white.withValues(alpha: 0.35),
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

