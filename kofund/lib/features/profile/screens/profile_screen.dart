import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/widgets/loading_indicator.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/skeleton/profile_screen_skeleton.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:kofund/core/widgets/glass_action_button.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
import 'package:kofund/features/admin/screens/approval_requests_screen.dart';
import './edit_profile_screen.dart';
import './participation_history_screen.dart';
import './contribution_history_screen.dart';
import './settings/settings_screen.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
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
        
        // Load all profile data
        await Future.wait([
          profileProvider.loadUserStatistics(userId: targetUserId),
          profileProvider.getUserParticipationHistory(userId: targetUserId),
          profileProvider.getUserContributionHistory(userId: targetUserId),
        ]);
        
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

    final bool showBackButton = widget.forceBackButton ?? (ModalRoute.of(context)?.canPop ?? false);

    // Debug info
    final firebaseUser = FirebaseAuth.instance.currentUser;
    debugPrint('🔍 BUILD - AppAuth user: ${authProvider.user?.uid}');
    debugPrint('🔍 BUILD - FirebaseAuth user: ${firebaseUser?.uid}');
    debugPrint('🔍 BUILD - Last loaded: $_lastLoadedUserId');
    debugPrint('🔍 BUILD - ProfileProvider isDataForCurrentUser: ${profileProvider.isDataForCurrentUser}');
    debugPrint('🔍 BUILD - ProfileProvider _loadedUserId: ${profileProvider.currentUserId}');

    // Check for user changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = authProvider.user?.uid;
      if (currentUserId != null && currentUserId != _lastLoadedUserId && !_isLoadingProfile) {
        _loadProfileData();
      }
    });

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
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildNewHeader(context, user),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _onRefresh,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildNewStatsRow(context, totalParticipations, totalContributions),
                const SizedBox(height: 24),
                _buildNewControlCenter(context, user),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewHeader(BuildContext context, UserModel user) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 10,
      ),
      child: Column(
        children: [
          // Settings button at the top right
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCircularIconButton(
                  context,
                  icon: Icons.settings_outlined,
                  onTap: _navigateToSettings,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Overlapping Avatar and Profile Card
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
                child: _buildNewProfileCard(context, user),
              ),
              _buildLargeAvatar(context, user),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIconButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
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
          icon,
          size: 20,
          color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildLargeAvatar(BuildContext context, UserModel user) {
    final String initial = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()[0].toUpperCase()
        : 'U';
    
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF00BFA5), // Teal from image
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.darkBackground 
              : AppColors.lightBackground,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNewProfileCard(BuildContext context, UserModel user) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E2E).withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
        ],
      ),
      child: Column(
        children: [
          Text(
            user.displayName ?? 'Unnamed Member',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary(context).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_rounded,
                  size: 14,
                  color: Color(0xFF00BFA5),
                ),
                SizedBox(width: 8),
                Text(
                  'COMMUNITY ADMIN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00BFA5),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewStatsRow(BuildContext context, int participations, int contributions) {
    return Row(
      children: [
        Expanded(
          child: _buildNewStatCard(
            context,
            label: 'ACTIVITIES',
            value: participations.toString(),
            icon: Icons.flash_on_rounded,
            iconColor: const Color(0xFF00D2B4),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNewStatCard(
            context,
            label: 'CONTRIBUTIONS',
            value: contributions.toString(),
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF00D2B4),
          ),
        ),
      ],
    );
  }

  Widget _buildNewStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context).withValues(alpha: 0.4),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewControlCenter(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'CONTROL CENTER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context).withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) 
                : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              if (Theme.of(context).brightness != Brightness.dark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Column(
            children: [
              _buildNewControlRow(
                context,
                icon: Icons.edit_note_rounded,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                onTap: () => _navigateToEditProfile(user),
              ),
              _buildNewControlRow(
                context,
                icon: Icons.history_rounded,
                title: 'Participation History',
                subtitle: 'Check your community involvement',
                onTap: _navigateToParticipationHistory,
              ),
              _buildNewControlRow(
                context,
                icon: Icons.receipt_long_rounded,
                title: 'Contribution History',
                subtitle: 'View your financial record',
                onTap: _navigateToContributionHistory,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewControlRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast 
          ? const BorderRadius.vertical(bottom: Radius.circular(32))
          : title == 'Edit Profile'
            ? const BorderRadius.vertical(top: Radius.circular(32))
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:  Icon(
                  icon,
                  size: 22,
                  color: Color(0xFF00BFA5),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary(context).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
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

