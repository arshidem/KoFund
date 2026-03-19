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
          _buildSliverAppBar(user),
          CupertinoSliverRefreshControl(
            onRefresh: _onRefresh,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20), // Top padding for stats
                  _buildNeonStatsRow(
                    totalParticipations,
                    totalContributions,
                    totalContributed,
                  ),
                  const SizedBox(height: 32),
                  _buildControlCenterSection(context, user),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 340,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.background(context),
      automaticallyImplyLeading: false,
      leading: widget.forceBackButton == true || (ModalRoute.of(context)?.canPop ?? false)
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, 
                color: AppColors.textPrimary(context), size: 20),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: GlassActionButton(
              icon: Icons.settings_outlined,
              size: 44,
              iconSize: 20,
              onTap: _navigateToSettings,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Aesthetic Radial Glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [
                      AppColors.primary(context).withValues(alpha: 0.15),
                      AppColors.background(context),
                    ],
                    stops: const [0.0, 0.85],
                  ),
                ),
              ),
            ),
            
            // Avatar & Info (Centered in the expanded area)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildFloatingAvatar(user),
                const SizedBox(height: 16),
                _buildPremiumProfileInfo(user),
                const SizedBox(height: 30), // Margin before stats row
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAvatar(UserModel user) {
    final String initial = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()[0].toUpperCase()
        : 'U';

    final Color primaryColor = AppColors.primary(context);
    final Color cardColor = AppColors.card(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cardColor,
        border: Border.all(color: primaryColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimary(context),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumProfileInfo(UserModel user) {
    return Column(
      children: [
        Text(
          user.displayName ?? 'Unnamed Member',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          user.email,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context).withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (user.isAdmin ? const Color(0xFFFFB800) : const Color(0xFF00D2B4)).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (user.isAdmin ? const Color(0xFFFFB800) : const Color(0xFF00D2B4)).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                size: 14,
                color: user.isAdmin ? const Color(0xFFFFB800) : const Color(0xFF00D2B4),
              ),
              const SizedBox(width: 6),
              Text(
                user.isAdmin ? 'COMMUNITY ADMIN' : 'MEMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: user.isAdmin ? const Color(0xFFFFB800) : const Color(0xFF00D2B4),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNeonStatsRow(int participations, int contributions, double total) {
    return Row(
      children: [
        Expanded(
          child: _buildModernStatCard(
            label: 'ACTIVITIES',
            value: participations.toString(),
            icon: Icons.flash_on_rounded,
            color: const Color(0xFF00D2B4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModernStatCard(
            label: 'CONTRIBUTIONS',
            value: contributions.toString(),
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFFFB800), // Gold
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final Color primaryColor = AppColors.primary(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context).withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCenterSection(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'CONTROL CENTER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(context),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildControlRow(
                icon: Icons.edit_note_rounded,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                onTap: () => _navigateToEditProfile(user),
              ),
              _buildDivider(),
              _buildControlRow(
                icon: Icons.history_rounded,
                title: 'Participation History',
                subtitle: 'Check your community involvement',
                onTap: _navigateToParticipationHistory,
              ),
              _buildDivider(),
              _buildControlRow(
                icon: Icons.receipt_long_rounded,
                title: 'Contribution History',
                subtitle: 'View your financial record',
                onTap: _navigateToContributionHistory,
              ),
              _buildDivider(),
              _buildControlRow(
                icon: Icons.security_rounded,
                title: 'Security Settings',
                subtitle: 'Manage your account safety',
                onTap: _navigateToSettings,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast 
          ? const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))
          : title == 'Edit Profile' 
            ? const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary(context)),
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
                        fontWeight: FontWeight.w700,
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

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      endIndent: 20,
      color: AppColors.textPrimary(context).withValues(alpha: 0.05),
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

