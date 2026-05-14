import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'dart:ui' as dart_ui;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/skeleton/profile_screen_skeleton.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import './edit_profile_screen.dart';
import './participation_history_screen.dart';
import './contribution_history_screen.dart';
import './settings/settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class ProfileScreen extends StatefulWidget {
  final bool? forceBackButton;

  const ProfileScreen({super.key, this.forceBackButton});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  bool _isInitialLoad = true;
  bool _isLoadingProfile = false;
  String? _lastLoadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData(forceRefresh: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUserAndLoadData();
    }
  }

  void _checkUserAndLoadData() {
    final _authProvider = context.read<AppAuthProvider>();
    final currentUserId = _authProvider.user?.uid;
    
    if (currentUserId != null && currentUserId != _lastLoadedUserId) {
      debugPrint('🔄 User changed from $_lastLoadedUserId to $currentUserId');
      _loadProfileData();
    }
  }

  Future<void> _loadProfileData({bool forceRefresh = false}) async {
    if (!mounted || _isLoadingProfile) return;
    
    setState(() {
      _isLoadingProfile = true;
    });
    
    try {
      final profileProvider = context.read<ProfileProvider>();
      final _authProvider = context.read<AppAuthProvider>();
      
      final currentUser = _authProvider.user;
      if (currentUser == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      // Also check FirebaseAuth directly
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('❌ No Firebase user');
        return;
      }

      debugPrint('🔄 Loading profile data for user: ${currentUser.uid}...');
      debugPrint('🔍 FirebaseAuth user: ${firebaseUser.uid}');
      debugPrint('🔍 Last loaded user: $_lastLoadedUserId');
      
      // Check if user IDs match between providers
      if (currentUser.uid != firebaseUser.uid) {
        debugPrint('⚠️ WARNING: AppAuthProvider and FirebaseAuth user IDs don\'t match!');
        debugPrint('⚠️ AppAuthProvider: ${currentUser.uid}');
        debugPrint('⚠️ FirebaseAuth: ${firebaseUser.uid}');
        
        // Force clear data and use FirebaseAuth user
        profileProvider.clearAllUserData();
        _lastLoadedUserId = null;
      }
      
      // Use FirebaseAuth user as source of truth
      final targetUserId = firebaseUser.uid;
      
      // Check if we need to load data
      if (!forceRefresh && _lastLoadedUserId == targetUserId) {
        debugPrint('✅ Already loaded data for user $targetUserId');
      } else {
        // Clear old data if user changed
        if (_lastLoadedUserId != null && _lastLoadedUserId != targetUserId) {
          debugPrint('🔄 Switching users from $_lastLoadedUserId to $targetUserId');
          profileProvider.clearAllUserData();
        }
        
        // ✅ NEW: Load all profile data in parallel with one call
        await profileProvider.loadFullProfileData(
          userId: targetUserId,
          communityId: currentUser.communityId ?? '',
          forceRefresh: forceRefresh,
        );
        
        // Update last loaded user
        _lastLoadedUserId = targetUserId;
        debugPrint('✅ Profile data loaded successfully for user: $targetUserId');
      }
      
    } catch (e) {
      debugPrint('❌ Error loading profile data: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load profile data');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    HapticHelper.light();
    debugPrint('🔄 Pull to refresh triggered');
    
    try {
      await _loadProfileData(forceRefresh: true);
      debugPrint('✅ Profile refresh completed');
    } catch (e) {
      debugPrint('❌ Profile refresh failed: $e');
    }
  }

  // Navigation methods
  void _navigateToEditProfile(UserModel user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: user,
          onProfileUpdated: () {
            _loadProfileData();
          },
        ),
      ),
    );
    
    if (mounted) {
      await _loadProfileData();
      if (!mounted) return;
    }
  }

  void _navigateToParticipationHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParticipationHistoryScreen()),
    );
    
    if (mounted) {
      await _loadProfileData();
      if (!mounted) return;
    }
  }

  void _navigateToContributionHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContributionHistoryScreen()),
    );
    
    if (mounted) {
      await _loadProfileData();
      if (!mounted) return;
    }
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    
    if (mounted) {
      await _loadProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final _authProvider = context.watch<AppAuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    // No back button needed in profile screen main view
    final bool showBackButton = false;

   // With this:
if (_isInitialLoad || _authProvider.user == null) {
  return ProfileScreenSkeleton(
    isDarkMode: Theme.of(context).brightness == Brightness.dark,
    showBackButton: showBackButton,
  );
}

    final user = _authProvider.user!;
    
    // TEMPORARY FIX: Show loading only if we're actively loading
    // Remove the profileProvider.isDataForCurrentUser check for now
  // Also replace the _isLoadingProfile state:
if (_isLoadingProfile) {
  return ProfileScreenSkeleton(
    isDarkMode: Theme.of(context).brightness == Brightness.dark,
    showBackButton: showBackButton,
  );
}

    // Get stats - even if check fails, show what we have
    final stats = profileProvider.getUserStatistics();
    
    final totalParticipations = stats['participations'] as int? ?? 0;
    final totalContributions = stats['contributions'] as int? ?? 0;
    final totalContributed = stats['totalContributed'] as double? ?? 0.0;

    // Get recent data for lists if needed later
    // final recentEvents = profileProvider.participationHistory.take(3).toList();
    // final recentContributions = profileProvider.contributionHistory.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context, user),
          ];
        },
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: _onRefresh,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  _buildMetricBoard(context, totalParticipations, totalContributions),
                  const SizedBox(height: 32),
                  _buildNewControlCenter(context, user),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSliverAppBar(BuildContext context, UserModel user) {
    final String initial = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()[0].toUpperCase()
        : 'U';
        
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
        
    return SliverAppBar(
      expandedHeight: 300,
      toolbarHeight: 90,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: AppColors.background(context),
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: _buildCircularIconButton(
            context,
            icon: Icons.settings_outlined,
            onTap: _navigateToSettings,
          ),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double topPadding = MediaQuery.of(context).padding.top;
          final double collapsedHeight = 90 + topPadding + 28;
          final double expandedHeight = 280.0;
          
          final double expandRatio = ((constraints.maxHeight - collapsedHeight) / 
              (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

          // Expanded content: visible until ratio drops below 0.6, then fades quickly
          // (mapped from [0.6 → 0.0] to opacity [1.0 → 0.0])
          final double expandedOpacity = ((expandRatio - 0.0) / 0.6).clamp(0.0, 1.0);

          // Collapsed content: only starts appearing in the last 25% of travel
          // (mapped from [0.25 → 0.0] ratio to opacity [0.0 → 1.0])
          final double collapsedOpacity = (1.0 - (expandRatio / 0.25)).clamp(0.0, 1.0);
          
          final bool isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. COLLAPSED VERSION (Small Left Aligned)
                Positioned(
                  left: 20,
                  top: topPadding + 20,
                  child: Opacity(
                    opacity: collapsedOpacity,
                    child: Row(
                      children: [
                        _buildProfileAvatar(context, user, isDark, size: 52, initial: initial, fontSize: 24, expandRatio: 0),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.displayName ?? 'Unnnamed',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : AppColors.textPrimary(context)).withValues(alpha: 0.6),
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
                  top: topPadding + 20, // Moved up to prEvent overflow
                  child: Opacity(
                    opacity: expandedOpacity,
                    child: Column(
                      children: [
                        _buildProfileAvatar(context, user, isDark, size: 100, initial: initial, fontSize: 40, expandRatio: expandRatio),
                        const SizedBox(height: 16),
                        Text(
                          "Welcome back,",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white : AppColors.textPrimary(context)).withValues(alpha: 0.6),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.displayName ?? 'Unnnamed Member',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.textPrimary(context),
                            letterSpacing: -0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: (isDark ? Colors.white : AppColors.textPrimary(context)).withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.primary(context).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00BFA6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'COMMUNITY MEMBER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBoard(BuildContext context, int participations, int contributions) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final profileProvider = context.watch<ProfileProvider>();
    final stats = profileProvider.getUserStatistics();
    
    // Get the actual total amount contributed
    final totalContributed = stats['totalContributedFromContributions'] as double? ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricItem(
            context,
            label: 'EVENTS',
            value: participations.toString(),
            icon: Icons.event_available_rounded,
            iconColor: const Color(0xFF00D2B4),
          ),
          Container(
            height: 60,
            width: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
          ),
          _buildMetricItem(
            context,
            label: 'TOTAL (₹)',
            value: totalContributed >= 1000 
                ? '${(totalContributed / 1000).toStringAsFixed(1)}K' 
                : totalContributed.toStringAsFixed(0),
            icon: Icons.currency_rupee_rounded,
            iconColor: const Color(0xFF00D2B4),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 30, color: iconColor),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context).withValues(alpha: 0.4),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCircularIconButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewControlCenter(BuildContext context, UserModel user) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'SETTINGS & HISTORY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context).withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Column(
            children: [
              _buildControlItem(
                context,
                icon: Icons.edit_note_rounded,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                onTap: () => _navigateToEditProfile(user),
              ),
              _buildDivider(isDark),
              _buildControlItem(
                context,
                icon: Icons.history_rounded,
                title: 'Participation History',
                subtitle: 'Check your community involvement',
                onTap: _navigateToParticipationHistory,
              ),
              _buildDivider(isDark),
              _buildControlItem(
                context,
                icon: Icons.receipt_long_rounded,
                title: 'Contribution History',
                subtitle: 'View your financial records',
                onTap: _navigateToContributionHistory,
              ),
              _buildDivider(isDark),
              _buildControlItem(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'App preferences and account security',
                onTap: _navigateToSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      endIndent: 20,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
    );
  }

  Widget _buildControlItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF00BFA5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.textPrimary(context).withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      default:
        return method;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildProfileAvatar(BuildContext context, UserModel user, bool isDark, {required double size, required String initial, required double fontSize, required double expandRatio}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (expandRatio > 0.1)
            BoxShadow(
              color: AppColors.primary(context).withValues(alpha: 0.15 * expandRatio),
              blurRadius: 20 * expandRatio,
              spreadRadius: 5 * expandRatio,
            ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.8) : AppColors.textPrimary(context).withValues(alpha: 0.6),
                width: dart_ui.lerpDouble(1.5, 3.0, expandRatio)!,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ClipOval(
              child: _buildAvatarPlaceholder(isDark, initial, fontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark, String initial, double fontSize) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ]
              : [
                  AppColors.primary(context).withValues(alpha: 0.1),
                  AppColors.primary(context).withValues(alpha: 0.05),
                ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}






