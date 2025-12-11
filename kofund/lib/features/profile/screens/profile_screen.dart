import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/widgets/loading_indicator.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
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
      print('🔄 User changed from $_lastLoadedUserId to $currentUserId');
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
        print('❌ No user logged in');
        return;
      }

      // Also check FirebaseAuth directly
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        print('❌ No Firebase user');
        return;
      }

      print('🔄 Loading profile data for user: ${currentUser.uid}...');
      print('🔍 FirebaseAuth user: ${firebaseUser.uid}');
      print('🔍 Last loaded user: $_lastLoadedUserId');
      
      // Check if user IDs match between providers
      if (currentUser.uid != firebaseUser.uid) {
        print('⚠️ WARNING: AppAuthProvider and FirebaseAuth user IDs don\'t match!');
        print('⚠️ AppAuthProvider: ${currentUser.uid}');
        print('⚠️ FirebaseAuth: ${firebaseUser.uid}');
        
        // Force clear data and use FirebaseAuth user
        profileProvider.clearAllUserData();
        _lastLoadedUserId = null;
      }
      
      // Use FirebaseAuth user as source of truth
      final targetUserId = firebaseUser.uid;
      
      // Check if we need to load data
      if (!forceRefresh && _lastLoadedUserId == targetUserId) {
        print('✅ Already loaded data for user $targetUserId');
      } else {
        // Clear old data if user changed
        if (_lastLoadedUserId != null && _lastLoadedUserId != targetUserId) {
          print('🔄 Switching users from $_lastLoadedUserId to $targetUserId');
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
        print('✅ Profile data loaded successfully for user: $targetUserId');
      }
      
    } catch (e) {
      print('❌ Error loading profile data: $e');
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
    print('🔄 Pull to refresh triggered');
    
    try {
      await _loadProfileData(forceRefresh: true);
      _refreshController.refreshCompleted();
      print('✅ Profile refresh completed');
    } catch (e) {
      _refreshController.refreshFailed();
      print('❌ Profile refresh failed: $e');
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
    }
  }

  void _navigateToParticipationHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParticipationHistoryScreen()),
    );
    
    if (mounted) {
      await _loadProfileData();
    }
  }

  void _navigateToContributionHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContributionHistoryScreen()),
    );
    
    if (mounted) {
      await _loadProfileData();
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
    print('🔍 BUILD - AppAuth user: ${authProvider.user?.uid}');
    print('🔍 BUILD - FirebaseAuth user: ${firebaseUser?.uid}');
    print('🔍 BUILD - Last loaded: $_lastLoadedUserId');
    print('🔍 BUILD - ProfileProvider isDataForCurrentUser: ${profileProvider.isDataForCurrentUser}');
    print('🔍 BUILD - ProfileProvider _loadedUserId: ${profileProvider.currentUserId}');

    // Check for user changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = authProvider.user?.uid;
      if (currentUserId != null && currentUserId != _lastLoadedUserId && !_isLoadingProfile) {
        _loadProfileData();
      }
    });

    if (_isInitialLoad || authProvider.user == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: _buildAppBar(showBackButton),
        body: const Center(child: LoadingIndicator()),
      );
    }

    final user = authProvider.user!;
    
    // TEMPORARY FIX: Show loading only if we're actively loading
    // Remove the profileProvider.isDataForCurrentUser check for now
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: _buildAppBar(showBackButton),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading ${user.displayName}\'s profile...'),
              SizedBox(height: 8),
              Text('User ID: ${user.uid.substring(0, 10)}...'),
            ],
          ),
        ),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Show warning if user mismatch
                if (!profileProvider.isDataForCurrentUser && profileProvider.participationHistory.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
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
                const SizedBox(height: 24),
                _buildStatisticsCards(
                  totalParticipations,
                  totalContributions,
                  totalContributed,
                ),
                
                // Recent Programs List
                if (recentPrograms.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildRecentProgramsList(recentPrograms),
                ],
                
                // Recent Contributions List
                if (recentContributions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildRecentContributionsList(recentContributions),
                ],
                
                const SizedBox(height: 24),
                _buildAccountInfo(user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool showBackButton) {
    return AppBar(
      title: const Text('Profile'),
      centerTitle: true,
      leading: showBackButton 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
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
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 6),
          child: IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).appBarTheme.foregroundColor,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient(context),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(context).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary(context).withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                              padding: EdgeInsets.zero,
                              onPressed: () => _navigateToEditProfile(user),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName ?? 'No Name',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.phoneNumber!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                if (user.communityId != null) 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Community Member',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(int participations, int contributions, double totalAmount) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Participations',
            value: participations.toString(),
            icon: Icons.event,
            color: Colors.blue,
            onTap: _navigateToParticipationHistory,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Contributions',
            value: contributions.toString(),
            subtitle: '₹${totalAmount.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: Colors.green,
            onTap: _navigateToContributionHistory,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 24, color: color),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Recent Programs List
  Widget _buildRecentProgramsList(List<Map<String, dynamic>> programs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Programs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (programs.length >= 3)
                      TextButton(
                        onPressed: _navigateToParticipationHistory,
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: programs.map((program) => _buildProgramListItem(program)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Program List Item
  Widget _buildProgramListItem(Map<String, dynamic> program) {
    final programTitle = program['programTitle'] ?? 'Unknown Program';
    final joinedAt = program['joinedAt'] is Timestamp 
        ? program['joinedAt'].toDate() 
        : DateTime.now();
    final hasPaid = program['hasPaidContribution'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _navigateToParticipationHistory,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event,
                    size: 20,
                    color: AppColors.primary(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Joined ${_formatRelativeDate(joinedAt)}',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasPaid ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    hasPaid ? 'Paid' : 'Pending',
                    style: TextStyle(
                      color: hasPaid ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Recent Contributions List
  Widget _buildRecentContributionsList(List<Map<String, dynamic>> contributions) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Contributions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (contributions.length >= 5)
                      TextButton(
                        onPressed: _navigateToContributionHistory,
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: contributions.map((contribution) => _buildContributionListItem(contribution)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Contribution List Item
  Widget _buildContributionListItem(Map<String, dynamic> contribution) {
    final programTitle = contribution['programTitle'] ?? 'Unknown Program';
    final amount = contribution['amount'] ?? 0.0;
    final createdAt = contribution['createdAt'] is Timestamp 
        ? contribution['createdAt'].toDate() 
        : DateTime.now();
    final paymentMethod = contribution['paymentMethod'] ?? 'cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _navigateToContributionHistory,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.payments,
                    size: 20,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatRelativeDate(createdAt)} • ${_formatPaymentMethod(paymentMethod)}',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountInfo(UserModel user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('User ID', user.uid),
                _buildInfoRow('Member Since', _formatDate(user.createdAt)),
                _buildInfoRow('Role', user.role.toUpperCase()),
                _buildInfoRow('Status', user.isApproved ? 'Approved' : 'Pending Approval'),
                if (user.communityCode != null) 
                  _buildInfoRow('Community Code', user.communityCode!),
              ],
            ),
          ),
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
      case 'online': return 'Online';
      case 'upi': return 'UPI';
      case 'bank_transfer': return 'Bank Transfer';
      default: return method;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}