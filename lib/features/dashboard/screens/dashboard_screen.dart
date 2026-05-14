// lib/features/community/screens/dashboard_screen.dart
import 'package:kofund/core/skeleton/stats_card_skeleton.dart';
import 'package:kofund/core/skeleton/event_card_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:clipboard/clipboard.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/members_widget.dart';

import 'package:kofund/routing/route_names.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';
import 'package:kofund/core/widgets/admin_assistant_toast.dart';
import '../../../features/events/providers/event_provider.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/dashboard/widgets/event_carousel_widget.dart';
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
import 'package:cached_network_image/cached_network_image.dart';

// ADD THESE IMPORTS
import 'package:badges/badges.dart' as badges;
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/members/providers/member_provider.dart';
import 'package:kofund/features/notifications/providers/announcement_provider.dart';
import 'package:kofund/features/notifications/widgets/announcement_bottom_sheet.dart';
import 'package:kofund/features/notifications/widgets/announcement_on_open_modal.dart';
import 'package:kofund/features/notifications/widgets/app_update_dialog.dart';
import 'package:kofund/core/services/app_update_service.dart';
import 'package:kofund/features/notifications/services/announcement_service.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

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
  final bool _showGreeting = true;
  final double _greetingOpacity = 1.0;

Future<void> _onRefresh() async {
  HapticHelper.light();
  // debugPrint('🔄 DEBUG: Pull to refresh triggered in Dashboard');
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
        context.read<EventProvider>().loadEvents(cid, forceRefresh: true),
        context.read<EventProvider>().loadMyParticipations(user.uid, cid),
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
      /*
      debugPrint('👤 DEBUG: User/Community changed in DashboardScreen');
      debugPrint('   Previous user: $_previousUserId, community: $_previousCommunityId');
      debugPrint('   New user: $currentUserId, community: $currentCommunityId');
      */
      
      _previousUserId = currentUserId;
      _previousCommunityId = currentCommunityId;
      
      // Reset dashboard state for new user
      _resetDashboardForNewUser();
    }
  }

  void _resetDashboardForNewUser() {
    // debugPrint('🔄 DEBUG: Resetting dashboard for new user/community');
    
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
      

      
      // Load freshhh data
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
        // debugPrint('🔄 DEBUG: Initializing dashboard data for community: $communityId');
        
        // ✅ Load dashboard data
        context.read<DashboardProvider>().loadDashboardData(communityId!);
        
        // ✅ Load events data  
        context.read<EventProvider>().loadEvents(communityId!);
        
        // ✅ CRITICAL: Load user participations
        context.read<EventProvider>().loadMyParticipations(user.uid, communityId!);
        
        // ✅ Set up participation listener
        context.read<EventProvider>().watchUserParticipation(communityId!, user.uid);
        
        // ✅ Initialize widget providers
        _initializeWidgetProviders(user.uid, communityId!);
        
        // 🆕 Check admin permissions and load invite info
        _checkAdminPermissions(user.uid, communityId!);

        // 🚀 Check for App Updates and Announcements
        _checkForAppUpdate();
        _checkAnnouncements();
        
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
      final _authProvider = context.read<AppAuthProvider>();
      final user = _authProvider.user;
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

  // 🚀 Internal method to check for app updates
  void _checkForAppUpdate() async {
    // Small delay to ensure UI is ready
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final updateInfo = await AppUpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      AppUpdateDialog.show(context, updateInfo);
    }
  }

  // 🚀 Internal method to check for new announcements
  void _checkAnnouncements() async {
    final announcementProvider = context.read<AnnouncementProvider>();
    await announcementProvider.refreshAnnouncements();
    
    if (!mounted) return;

    // Check if any high-priority announcements should be shown as a modal
    final popups = announcementProvider.unreadAnnouncements
        .where((a) => a['show_on_open'] == true)
        .toList();

    if (popups.isNotEmpty) {
      final announcement = popups.first;
      AnnouncementOnOpenModal.show(
        context,
        announcement: announcement,
        onDismiss: () => announcementProvider.markAsRead(announcement['id']),
      );
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
      SnackbarHelper.showError(context, 'No community found');
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
      SnackbarHelper.showError(context, 'Error: $e');
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
    
    SnackbarHelper.showSuccess(context, 'Invite code copied to clipboard!');
  }

  // 🆕 Copy invite link to clipboard
  void _copyInviteLink() async {
    if (_inviteLink.isEmpty) return;
    
    await FlutterClipboard.copy(_inviteLink);
    if (!mounted) return;
    
    SnackbarHelper.showSuccess(context, 'Invite link copied to clipboard!');
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

  Widget _buildNotificationIconButton(BuildContext context, {double size = 52, double iconSize = 20}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
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
                  position: badges.BadgePosition.topEnd(top: size == 52 ? -6 : -8, end: size == 52 ? -6 : -8),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: isDark ? Colors.white : AppColors.textPrimary(context),
                      size: iconSize,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String? logoUrl = stats['clubLogo'];
    final String clubName = (stats['clubName'] != null && stats['clubName'].toString().trim().isNotEmpty)
        ? stats['clubName']
        : (user?.communityName ?? 'Community');
    final String initial = clubName.isNotEmpty ? clubName[0].toUpperCase() : 'C';

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.primary(context).withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitialPlaceholder(initial, size),
                errorWidget: (context, url, error) => _buildInitialPlaceholder(initial, size),
              ),
            )
          : _buildInitialPlaceholder(initial, size),
    );

    return avatar;
  }

  Widget _buildInitialPlaceholder(String initial, double size) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textPrimary(context),
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
        virtualUserService: VirtualUserService(),
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
    // ✅ FIXED: Pass UserService parnameter
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
          
          // ✅ SYNC COMMUNITY NAME WITH USER PROFILE IF IT CHANGED
          final String freshhhName = stats['clubName']?.toString() ?? '';
          if (freshhhName.isNotEmpty && freshhhName != (user?.communityName ?? '')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<AppAuthProvider>().syncCommunityName(freshhhName);
              }
            });
          }

          return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            _buildDashboardSliverAppBar(stats, isDarkMode, cid, user, showSkeleton),
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
                    EventCardSkeleton(isDarkMode: isDarkMode),
                    const SizedBox(height: 24),
                    MembersSkeleton(isDarkMode: isDarkMode),
                  ] else ...[
                    _buildStatsCard(stats, isDarkMode),
                    const SizedBox(height: AppDimensions.spaceMedium),
                    
                    CarouselWidget(
                      isAdmin: user?.isAdmin ?? false,
                      key: ValueKey('events-$userId-$cid-${_isManualRefreshing ? "ref" : "stable"}'),
                    ),
                    const SizedBox(height: 16),
                    
                    MembersWidget(
                      key: ValueKey('members-$userId-$cid-${_isManualRefreshing ? "ref" : "stable"}'),
                      onSeeAll: widget.onNavigateToMembers,
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
          Consumer<AnnouncementProvider>(
            builder: (context, provider, child) {
              if (!provider.hasAnyAnnouncements) return const SizedBox.shrink();
              final hasUnread = provider.unreadCount > 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FloatingActionButton(
                  heroTag: 'announcement_fab',
                  onPressed: () {
                    HapticHelper.light();
                    AnnouncementBottomSheet.show(context);
                  },
                  // Red when unread, neutral (same as invite FAB) when all read
                  backgroundColor: hasUnread
                      ? AppColors.error(context)
                      : AppColors.primary(context),
                  foregroundColor: Colors.white,
                  child: hasUnread
                      ? badges.Badge(
                          showBadge: true,
                          position: badges.BadgePosition.topEnd(top: -4, end: -4),
                          badgeStyle: const badges.BadgeStyle(
                            badgeColor: Colors.white,
                            padding: EdgeInsets.all(4),
                            elevation: 0,
                          ),
                          badgeContent: Text(
                            provider.unreadCount > 9 ? '9+' : provider.unreadCount.toString(),
                            style: TextStyle(
                              color: AppColors.error(context),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Icon(Icons.campaign_outlined),
                        )
                      : const Icon(Icons.campaign_outlined),
                ),
              );
            },
          ),
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

  Widget _buildDashboardSliverAppBar(Map<String, dynamic> stats, bool isDarkMode, String? cid, UserModel? user, bool showSkeleton) {
    final bool isAdmin = user?.isAdmin ?? false;
    
    return SliverAppBar(
      expandedHeight:280,
      toolbarHeight: 90,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: AppColors.background(context),
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(18),
        child: Container(
          height: 18,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppDimensions.radiusExtraLarge),
              topRight: Radius.circular(AppDimensions.radiusExtraLarge),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.15 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildNotificationIconButton(context),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double topPadding = MediaQuery.of(context).padding.top;
          final double collapsedHeight = 90 + topPadding + 28;
          final double expandedHeight = 305.0;
          
          final double expandRatio = ((constraints.maxHeight - collapsedHeight) / 
              (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

          // Expanded content: visible until ratio drops below 0.6, then fades quickly
          // (mapped from [0.6 → 0.0] to opacity [1.0 → 0.0])
          final double expandedOpacity = ((expandRatio - 0.0) / 0.6).clamp(0.0, 1.0);

          // Collapsed content: only starts appearing in the last 25% of travel
          // (mapped from [0.25 → 0.0] ratio to opacity [0.0 → 1.0])
          final double collapsedOpacity = (1.0 - (expandRatio / 0.25)).clamp(0.0, 1.0);
          
          final String providerClubName = stats['clubName']?.toString().trim() ?? '';
          final bool hasProviderName = providerClubName.isNotEmpty;
          
          // CRITICAL: If we are in the initial loading state (showSkeleton), 
          // we don't want to show a potentially stale cached name from user profile.
          // This ps the flicker between the old cached name and the freshhh server name.
          final String clubName = hasProviderName 
              ? providerClubName 
              : (showSkeleton ? "" : (user?.communityName ?? ""));
              
          final bool showNameShimmer = showSkeleton && !hasProviderName;

          return Container(
            decoration: BoxDecoration(
              gradient: isDarkMode
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. COLLAPSED VERSION (Small Left Aligned)
                Positioned(
                  left: 20,
                  top: topPadding + 15,
                  child: Opacity(
                    opacity: collapsedOpacity,
                    child: Row(
                      children: [
                        _buildCommunityAvatar(context, stats, cid, isAdmin, user, size: 60),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            showNameShimmer
                                ? _buildShimmerText(isDarkMode, 120, 18)
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        clubName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: isDarkMode ? Colors.white : AppColors.textPrimary(context),
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: _navigateToEditCommunity,
                                          child: Icon(
                                            Icons.edit_rounded,
                                            size: 14,
                                            color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : AppColors.textPrimary(context).withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                            Text(
                              "${stats['membersCount'] ?? 0} Members",
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDarkMode ? Colors.white : AppColors.textPrimary(context)).withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. EXPANDED VERSION (Large Centered)
                Positioned(
                  left: 0,
                  right: 0,
                  top: topPadding + 30, // Adjusted for safe fit
                  child: Opacity(
                    opacity: expandedOpacity,
                    child: Column(
                      children: [
                        _buildCommunityAvatar(context, stats, cid, isAdmin, user, size: 90),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: showNameShimmer
                                  ? _buildShimmerText(isDarkMode, 180, 24)
                                  : Text(
                                      clubName,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: isDarkMode ? Colors.white : AppColors.textPrimary(context),
                                        letterSpacing: -0.5,
                                      ),
                                      textAlign: TextAlign.center,
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
                                  color: isDarkMode 
                                      ? Colors.white.withValues(alpha: 0.85) 
                                      : AppColors.textPrimary(context).withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              size: 14,
                              color: (isDarkMode ? Colors.white : AppColors.textPrimary(context)).withValues(alpha: 0.8),
                            ),

                            const SizedBox(width: 6),
                            Text(
                              "${stats['membersCount'] ?? 0} Members",
                              style: TextStyle(
                                fontSize: 14,
                                color: (isDarkMode ? Colors.white : AppColors.textPrimary(context)).withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        if (_showGreeting) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                              border: Border.all(
                                color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              _getGreetingText(user?.displayName),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode ? Colors.white : AppColors.textPrimary(context),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),
                      ],
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2E2E), Color(0xFF0D1B1A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00C6A2), Color(0xFF00E3C3)],
              ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF00C6A2).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Community Treasury",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "₹${(stats['monthlyBalance'] ?? 0.0).toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                "Total Inflow",
                "₹${(stats['monthlyCollected'] ?? 0.0).toStringAsFixed(2)}",
                Colors.white,
                Colors.white.withValues(alpha: 0.7),
              ),
              _buildStatItem(
                "Total Outflow",
                "₹${(stats['monthlyExpenses'] ?? 0.0).toStringAsFixed(2)}",
                Colors.white,
                Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textSecondary.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 🆕 Helper for text shimmer to p flickering
  Widget _buildShimmerText(bool isDark, double width, double height) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
      highlightColor: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height / 4),
        ),
      ),
    );
  }
}






