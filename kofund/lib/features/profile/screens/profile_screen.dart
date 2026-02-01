import 'package:flutter/material.dart';
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
import 'package:pull_to_refresh/pull_to_refresh.dart';
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
  final RefreshController _refreshController = RefreshController();
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
    _refreshController.dispose();
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

  void _onRefresh() async {
    debugPrint('🔄 Pull to refresh triggered');
    
    try {
      await _loadProfileData(forceRefresh: true);
      _refreshController.refreshCompleted();
      debugPrint('✅ Profile refresh completed');
    } catch (e) {
      _refreshController.refreshFailed();
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

    // Get recent data for lists
    final recentPrograms = profileProvider.participationHistory.take(3).toList();
    final recentContributions = profileProvider.contributionHistory.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(showBackButton),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        enablePullDown: true,
        enablePullUp: false,
        physics: const BouncingScrollPhysics(),
        header: ClassicHeader(
          idleText: 'Pull down to refresh',
          releaseText: 'Release to refresh',
          refreshingText: 'Refreshing profile...',
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Show warning if user mismatch
                if (!profileProvider.isDataForCurrentUser && profileProvider.participationHistory.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing cached data. Pull to refresh for current user.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                _buildProfileHeader(user),
                const SizedBox(height: 8),
                _buildStatisticsCards(
                  totalParticipations,
                  totalContributions,
                  totalContributed,
                ),
                
                // Recent Programs List
                if (recentPrograms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildRecentProgramsList(recentPrograms),
                ],
                
                // Recent Contributions List
                if (recentContributions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildRecentContributionsList(recentContributions),
                ],
                
                // _buildAccountInfo(user),
              ],
            ),
          ),
        ),
      ),
    );
  }

AppBar _buildAppBar(bool showBackButton) {
  return AppBar(
    toolbarHeight: 80, // Set your desired height here (default is 56)
    title: const Text(
      'Profile',
      style: TextStyle(
        color: Colors.white, // White text like Members app bar
        fontSize: 18, // Same as Members app bar
        fontWeight: FontWeight.w600, // Same as Members app bar
      ),
    ),
    centerTitle: true,
    leading: showBackButton 
        ? IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white, // Explicitly set white color for back icon
            ),
            onPressed: () => Navigator.pop(context),
          )
        : null,
    automaticallyImplyLeading: showBackButton,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white, // This sets all icons to white
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
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 6),
        child: IconButton(
          icon: const Icon(
            Icons.settings,
            color: Colors.white, // Explicitly set white color for settings icon
            size: 22,
          ),
          onPressed: _navigateToSettings,
          splashRadius: 22,
        ),
      ),
    ],
  );
}

Widget _buildProfileHeader(UserModel user) {
  // ✅ Old gradient for avatar only
  final Gradient avatarGradient = AppColors.primaryGradient(context);

  // ✅ Safe initial
  final String initial =
      (user.displayName != null && user.displayName!.trim().isNotEmpty)
          ? user.displayName!.trim()[0].toUpperCase()
          : 'U';

  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card(context), // ✅ Card background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          /// Avatar + Edit
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              /// Avatar (Initial + Gradient)
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: avatarGradient, // ✅ Old gradient restored
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              /// Edit button
              Positioned(
                bottom: -4,
                right: -4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _navigateToEditProfile(user),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.card(context),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          /// Name
          Text(
            user.displayName ?? 'No Name',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
          ),

          const SizedBox(height: 6),

          /// Email
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary(context),
            ),
          ),

          /// Phone (optional)
          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user.phoneNumber!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],

          const SizedBox(height: 16),

          /// Status badge
          if (user.communityId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: user.isAdmin
                    ? Colors.orange.withValues(alpha: 0.15)
                    : AppColors.surface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: user.isAdmin
                      ? Colors.orange.withValues(alpha: 0.4)
                      : AppColors.border(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    user.isAdmin
                        ? Icons.admin_panel_settings
                        : Icons.group_rounded,
                    size: 16,
                    color: user.isAdmin
                        ? Colors.orange
                        : AppColors.textPrimary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    user.isAdmin
                        ? 'Community Admin'
                        : 'Community Member',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: user.isAdmin
                          ? Colors.orange
                          : AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}


Widget _buildStatisticsCards(
  int participations,
  int contributions,
  double totalAmount,
) {
  return Row(
    children: [
      Expanded(
        child: _buildStatCard(
          title: 'Participations',
          value: participations.toString(),
          icon: Icons.event,
          onTap: _navigateToParticipationHistory,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildStatCard(
          title: 'Contributions',
          value: contributions.toString(),
          icon: Icons.attach_money,
          onTap: _navigateToContributionHistory,
        ),
      ),
    ],
  );
}


Widget _buildStatCard({
  required String title,
  required String value,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.card(context), // ✅ CARD BG
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.border(context),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: AppColors.primary(context),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}



// Recent Programs List
Widget _buildRecentProgramsList(List<Map<String, dynamic>> programs) {
  if (programs.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 36,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 6),
          Text(
            'No recent programs',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header (compact)
          Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                size: 18,
                color: AppColors.primary(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Recent Programs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              if (programs.length >= 3)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _navigateToParticipationHistory,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          /// Program list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: programs.length,
            separatorBuilder: (_, __) => Divider(
              height: 10,
              thickness: 0.8,
              color: AppColors.border(context),
            ),
            itemBuilder: (context, index) {
              return _buildProgramListItem(programs[index]);
            },
          ),
        ],
      ),
    ),
  );
}
Widget _buildProgramListItem(Map<String, dynamic> program) {
  final programTitle = program['programTitle'] ?? 'Unknown Program';
  final joinedAt = program['joinedAt'] is Timestamp
      ? program['joinedAt'].toDate()
      : DateTime.now();
  final hasPaid = program['hasPaidContribution'] ?? false;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _navigateToParticipationHistory,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), // ⬇️ compact
        child: Row(
          children: [
            /// Icon
            Container(
              width: 36, // ⬇️
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.event_rounded,
                size: 18,
                color: AppColors.primary(context),
              ),
            ),

            const SizedBox(width: 10),

            /// Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    programTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13, // ⬇️
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Joined ${_formatRelativeDate(joinedAt)}',
                    style: TextStyle(
                      fontSize: 11, // ⬇️
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            /// Status badge (compact)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasPaid
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasPaid
                      ? Colors.green.withValues(alpha: 0.35)
                      : Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                hasPaid ? 'Paid' : 'Pending',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: hasPaid ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildRecentContributionsList(
  List<Map<String, dynamic>> contributions,
) {
  if (contributions.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 36,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 6),
          Text(
            'No recent contributions',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), // ⬇️ tighter
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header (compact)
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.primary(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Recent Contributions',
                  style: TextStyle(
                    fontSize: 16, // ⬇️
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              if (contributions.length >= 5)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _navigateToContributionHistory,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4), // ⬇️
                    child: Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4), // ⬇️

          /// List (compact separators)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: contributions.length,
            separatorBuilder: (_, __) => Divider(
              height: 10, // ⬇️
              thickness: 0.8,
              color: AppColors.border(context),
            ),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2), // ⬇️
                child: _buildContributionListItem(contributions[index]),
              );
            },
          ),
        ],
      ),
    ),
  );
}


Widget _buildContributionListItem(Map<String, dynamic> contribution) {
  final programTitle = contribution['programTitle'] ?? 'Unknown Program';
  final amount = (contribution['amount'] ?? 0).toDouble();
  final createdAt = contribution['createdAt'] is Timestamp
      ? contribution['createdAt'].toDate()
      : DateTime.now();
  final paymentMethod = contribution['paymentMethod'] ?? 'cash';

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _navigateToContributionHistory,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 8), // ⬇️ compact
        child: Row(
          children: [
            /// Icon
            Container(
              width: 34, // ⬇️
              height: 34,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.payments_rounded,
                size: 18,
                color: Colors.green,
              ),
            ),

            const SizedBox(width: 10),

            /// Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    programTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13, // ⬇️
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatRelativeDate(createdAt)} • ${_formatPaymentMethod(paymentMethod)}',
                    style: TextStyle(
                      fontSize: 11, // ⬇️
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            /// Amount
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13, // ⬇️
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


 Widget _buildAccountInfo(UserModel user) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            children: [
              Icon(
                Icons.manage_accounts_rounded,
                size: 18,
                color: AppColors.primary(context),
              ),
              const SizedBox(width: 6),
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _buildInfoRow('User ID', user.uid),
          _buildInfoRow('Member Since', _formatDate(user.createdAt)),
          _buildInfoRow('Role', user.isAdmin ? 'Admin' : 'Member'),
        ],
      ),
    ),
  );
}


  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  
  }

  // Helper method for relative dates
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

  // Helper method for payment method formatting
  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'upi': return 'UPI';
    
      default: return method;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

