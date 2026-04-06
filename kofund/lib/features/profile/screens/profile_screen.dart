import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      _loadProfileData(forceRefresh: true);
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
    final authProvider = context.read<AppAuthProvider>();
    final currentUserId = authProvider.user?.uid;
    
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
      final authProvider = context.read<AppAuthProvider>();
      
      final currentUser = authProvider.user;
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
    final authProvider = context.watch<AppAuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    // No back button needed in profile screen main view
    final bool showBackButton = false;

   // With this:
if (_isInitialLoad || authProvider.user == null) {
  return ProfileScreenSkeleton(
    isDarkMode: Theme.of(context).brightness == Brightness.dark,
    showBackButton: showBackButton,
  );
}

    final user = authProvider.user!;
    
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
    // final recentPrograms = profileProvider.participationHistory.take(3).toList();
    // final recentContributions = profileProvider.contributionHistory.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _onRefresh,
          ),
          _buildSliverAppBar(context, user),
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
    );
  }


  Widget _buildSliverAppBar(BuildContext context, UserModel user) {
    final String initial = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()[0].toUpperCase()
        : 'U';
        
    return SliverAppBar(
      expandedHeight: 340,
      toolbarHeight: 90,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
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
          final double expandedHeight = 340.0;
          
          final double expandRatio = ((constraints.maxHeight - collapsedHeight) / 
              (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

          final double expandedOpacity = (expandRatio * 2 - 1).clamp(0.0, 1.0);
          
          // Math for smooth Avatar sliding and scaling
          final double currentAvatarSize = dart_ui.lerpDouble(52.0, 106.0, expandRatio)!;
          final double currentAvatarX = dart_ui.lerpDouble(20.0, (constraints.maxWidth - currentAvatarSize) / 2, expandRatio)!;
          final double currentAvatarY = dart_ui.lerpDouble(topPadding + 20.0, topPadding + 40.0, expandRatio)!;
          final double currentFontSize = dart_ui.lerpDouble(24.0, 42.0, expandRatio)!;

          // Math for smooth Swarm translating and scaling
          final double arcOffset = (1 - (2 * expandRatio - 1).abs()); // Creates a 0->1->0 parabolic curve
          final double dodgeAmount = 40.0 * arcOffset; // Pushes text down by 40px at intersection peak
          
          final double currentNameTop = dart_ui.lerpDouble(22.0 + topPadding, 150.0 + topPadding, expandRatio)! + dodgeAmount;
          final double currentEmailTop = dart_ui.lerpDouble(50.0 + topPadding, 185.0 + topPadding, expandRatio)! + dodgeAmount;
          final double currentBadgeTop = dart_ui.lerpDouble(80.0 + topPadding, 215.0 + topPadding, expandRatio)! + dodgeAmount;
          
          final double currentLeftPadding = dart_ui.lerpDouble(84.0, 0.0, expandRatio)!;
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
                  child: Container(
                    width: currentAvatarSize,
                    height: currentAvatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                        color: Colors.white,
                        width: dart_ui.lerpDouble(2.0, 3.0, expandRatio)!,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1 * expandRatio),
                          blurRadius: 20 * expandRatio,
                          offset: Offset(0, 10 * expandRatio),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: currentFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. SWARMING NAME
                Positioned(
                  top: currentNameTop,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(left: currentLeftPadding, right: currentRightPadding),
                    child: Align(
                      alignment: Alignment(currentAlignmentX, 0),
                      child: Text(
                        user.displayName ?? 'Unnamed Member',
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
                  ),
                ),

                // 3. SWARMING EMAIL
                Positioned(
                  top: currentEmailTop,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(left: currentLeftPadding, right: currentRightPadding),
                    child: Align(
                      alignment: Alignment(currentAlignmentX, 0),
                      child: Text(
                        user.email,
                        style: TextStyle(
                          fontSize: dart_ui.lerpDouble(12.0, 14.0, expandRatio)!,
                          color: Colors.white.withValues(alpha: dart_ui.lerpDouble(0.7, 0.8, expandRatio)!),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                // 4. SWARMING BADGE
                if (expandedOpacity > 0)
                  Positioned(
                    top: currentBadgeTop,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.only(left: currentLeftPadding, right: currentRightPadding),
                      child: Align(
                        alignment: Alignment(currentAlignmentX, 0),
                        child: Opacity(
                          opacity: expandedOpacity,
                          child: Transform.scale(
                            scale: dart_ui.lerpDouble(0.8, 1.0, expandRatio)!,
                            alignment: Alignment(dart_ui.lerpDouble(-1.0, 0.0, expandRatio)!, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'COMMUNITY MEMBER',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildMetricBoard(BuildContext context, int participations, int contributions) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
            label: 'ACTIVITIES',
            value: participations.toString(),
            icon: Icons.flash_on_rounded,
            iconColor: const Color(0xFF00D2B4),
          ),
          Container(
            height: 60,
            width: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
          ),
          _buildMetricItem(
            context,
            label: 'CONTRIBUTIONS',
            value: contributions.toString(),
            icon: Icons.account_balance_wallet_rounded,
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
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
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
}

