// lib/features/members/screens/member_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/skeleton/member_details_skeleton.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/events/constants/event_Types.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/core/services/contribution_service.dart';
import 'package:kofund/core/services/virtual_user_service.dart';
import 'package:kofund/features/virtual_users/screens/edit_virtual_user_screen.dart';
import 'package:kofund/features/virtual_users/providers/virtual_user_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kofund/ads/simple_banner_ad.dart';

// =================== MAIN SCREEN ===================
class MemberProfileScreen extends StatelessWidget {
  final UserModel? member;

  const MemberProfileScreen({super.key, this.member});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    return ChangeNotifierProvider(
      create: (_) => MemberProvider(
        userService: UserService(),
        authProvider: auth,
        participantService: ParticipantService(),
        contributionService: ContributionService(),
        virtualUserService: VirtualUserService(),
      ),
      child: _MemberProfileScreenBody(member: member),
    );
  }
}

// =================== SCREEN BODY ===================
class _MemberProfileScreenBody extends StatefulWidget {
  final UserModel? member;

  const _MemberProfileScreenBody({this.member});

  @override
  State<_MemberProfileScreenBody> createState() =>
      _MemberProfileScreenBodyState();
}

// =================== SCREEN STATE ===================
class _MemberProfileScreenBodyState extends State<_MemberProfileScreenBody> {
  UserModel? _currentMember;
  bool _isLoading = false;

  // Track current user to detect changes
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 DEBUG: MemberProfileScreen initState called');
    _loadMemberData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if current user has changed (logout/login scenario)
    final _authProvider = context.read<AppAuthProvider>();
    final currentUser = _authProvider.user;

    if (currentUser?.uid != _currentUserId) {
      debugPrint(
        '👤 DEBUG: User changed in MemberProfileScreen - from $_currentUserId to ${currentUser?.uid}',
      );
      _currentUserId = currentUser?.uid;

      // Reset screen state for new user
      _resetScreenForNewUser();
    }
  }

  void _resetScreenForNewUser() {
    if (!mounted) return;

    debugPrint('🔄 DEBUG: Resetting MemberProfileScreen for new user');

    setState(() {
      _currentMember = null;
      _isLoading = false;
    });

    // Reset the provider as well
    final memberProvider = context.read<MemberProvider>();
    memberProvider.resetForNewUser();

    // Reload member data for the new user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMemberData();
    });
  }

  void _loadMemberData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      if (widget.member != null) {
        _currentMember = widget.member;
      } else {
        final memberProvider = context.read<MemberProvider>();
        final selectedMember = memberProvider.selectedMember;
        if (selectedMember != null) {
          _currentMember = selectedMember;

          final freshMember = await memberProvider.getMemberById(
            selectedMember.uid,
          );
          if (freshMember != null) {
            _currentMember = freshMember;
          }
        }
      }

      // Load history if admin or member has detailed profile
      if (_currentMember != null) {
        final currentUser = context.read<AppAuthProvider>().user;
        final isAdmin = currentUser?.isAdmin == true;
        final shouldLoadHistory =
            isAdmin || _currentMember!.showDetailedProfile;

        if (shouldLoadHistory) {
          await _loadMemberHistory();
        }
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Error loading member data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMemberHistory() async {
    if (_currentMember == null) return;

    final memberProvider = context.read<MemberProvider>();
    await memberProvider.loadMemberHistoryData(_currentMember!.uid);
  }

  Future<void> _refreshMemberData() async {
    try {
      setState(() => _isLoading = true);
      await _refreshMemberDataSilent();
    } catch (e) {
      debugPrint('❌ DEBUG: Error refreshing member data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshMemberDataSilent() async {
    if (_currentMember == null) return;
    
    try {
      final memberProvider = context.read<MemberProvider>();
      final freshMember = await memberProvider.getMemberById(_currentMember!.uid);
      
      if (freshMember != null && mounted) {
        setState(() {
          _currentMember = freshMember;
        });
      }

      // Load history if admin or member has detailed profile
      final currentUser = context.read<AppAuthProvider>().user;
      final isAdmin = currentUser?.isAdmin == true;
      final shouldLoadHistory = isAdmin || (_currentMember?.showDetailedProfile ?? false);

      if (shouldLoadHistory) {
        await memberProvider.loadMemberHistoryData(_currentMember!.uid);
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Error silent refreshing member data: $e');
    }
  }

  Future<void> _onRefresh() async {
    HapticHelper.light();
    await _refreshMemberData();
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AppAuthProvider>().user;
    final memberProvider = context.watch<MemberProvider>();
    final member = _currentMember;
    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark; // Add this

    if (_isLoading) {
      return GradientSheetScaffold(
        title: 'Member Profile',
        body: Column(
          children: [
            Expanded(child: MemberDetailsSkeleton()),
            // Banner ad in loading state
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: AppColors.background(context),
              child: const SimpleBannerAd(),
            ),
          ],
        ),
      );
    }

    if (member == null) {
      return GradientSheetScaffold(
        title: 'Profile Not Found',
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No results matching your search',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusFull,
                          ),
                        ),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
            // Banner ad in error state
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: AppColors.background(context),
              child: const SimpleBannerAd(),
            ),
          ],
        ),
      );
    }

    final isAdmin = currentUser?.isAdmin == true;
    final canSeeDetails = isAdmin || member.showDetailedProfile;
    final isVirtualUser = member.isVirtualUser;

    return GradientSheetScaffold(
      title: 'Member Profile',
      actions: _buildAdminActions(member, isAdmin, isVirtualUser, currentUser?.uid),
      body: Column(
        children: [
          // Main content
          Expanded(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Profile Header Card
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildProfileHeaderCard(
                          member,
                          isAdmin,
                          isVirtualUser,
                        ),
                      ),

                      // Virtual User Info Card (if virtual user)
                      if (isVirtualUser)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildVirtualUserInfoCard(member),
                        ),
                      const SizedBox(height: 12),

                      // Member Information
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildMemberInfoCard(
                          member,
                          canSeeDetails,
                          isAdmin,
                          isVirtualUser,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Participation History (Only if detailed profile enabled and not virtual user)
                      if (canSeeDetails)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildParticipationHistoryCard(memberProvider),
                        ),
                      const SizedBox(height: 12),

                      // Contribution History (Only if detailed profile enabled and not virtual user)
                      if (canSeeDetails)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildContributionHistoryCard(memberProvider),
                        ),
                      const SizedBox(height: 12),

                      // Privacy Notice (if details are hidden)
                      if (!canSeeDetails && !isAdmin && !isVirtualUser)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildPrivacyNotice(),
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Banner ad
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            color: AppColors.background(context),
            child: const SimpleBannerAd(),
          ),
        ],
      ),
    );
  }

  // Profile Header Card (Horizontal Rectangle)
  Widget _buildProfileHeaderCard(
    UserModel member,
    bool isAdmin,
    bool isVirtualUser,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
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
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF00C6A2).withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Initial Circle Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: isVirtualUser
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        member.displayName?.substring(0, 1).toUpperCase() ??
                            '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Member Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.displayName ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            member.email ?? 'No email',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (member.phoneNumber != null &&
                        member.phoneNumber!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            member.phoneNumber!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdminActions(
    UserModel member,
    bool isAdmin,
    bool isVirtualUser,
    String? currentUserId,
  ) {
    if (!isAdmin || member.uid == currentUserId) return [];

    PopupMenuItem<String> buildPopupMenuItem({
      required String value,
      required IconData icon,
      required String label,
      required Color color,
    }) {
      return PopupMenuItem<String>(
        value: value,
        height: 44,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );
    }

    return [
      PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          size: 24,
        ),
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        color: AppColors.card(context),
        onSelected: (value) => _handleMenuAction(value, member, isVirtualUser),
        itemBuilder: (context) {
          if (isVirtualUser) {
            // Virtual user menu
            return [
              buildPopupMenuItem(
                value: 'edit',
                icon: Icons.edit_rounded,
                label: 'Edit Virtual User',
                color: Colors.blue,
              ),
              buildPopupMenuItem(
                value: 'remove',
                icon: Icons.delete_outline_rounded,
                label: 'Remove from Community',
                color: AppColors.error(context),
              ),
            ];
          } else {
            // Regular user menu
            return [
              if (!member.isAdmin)
                buildPopupMenuItem(
                  value: 'make_admin',
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Make Admin',
                  color: Colors.orange,
                ),
              if (member.isAdmin)
                buildPopupMenuItem(
                  value: 'remove_admin',
                  icon: Icons.person_remove_rounded,
                  label: 'Remove Admin',
                  color: Colors.orange,
                ),
              buildPopupMenuItem(
                value: 'unapprove',
                icon: Icons.block_rounded,
                label: 'Unapprove User',
                color: AppColors.error(context),
              ),
              buildPopupMenuItem(
                value: 'remove',
                icon: Icons.exit_to_app_rounded,
                label: 'Remove from Community',
                color: AppColors.error(context),
              ),
            ];
          }
        },
      ),
    ];
  }

  // Virtual User Info Card
  Widget _buildVirtualUserInfoCard(UserModel member) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: AppColors.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: AppColors.textPrimary(context),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Virtual Member Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (member.createdByName != null &&
              member.createdByName!.isNotEmpty) ...[
            _buildVirtualInfoItem(
              'Created By Admin',
              member.createdByName!,
              Icons.person_add,
            ),
            const SizedBox(height: 12),
          ],

          if (member.createdAt != null) ...[
            _buildVirtualInfoItem(
              'Created On',
              _formatDateFromTimestamp(member.createdAt),
              Icons.calendar_today,
            ),
            const SizedBox(height: 12),
          ],

          // Note about virtual users
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary(context).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Virtual members don\'t have app access. They are managed by community admins.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualInfoItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Handle menu actions
  void _handleMenuAction(String action, UserModel member, bool isVirtualUser) {
    final memberProvider = context.read<MemberProvider>();

    switch (action) {
      case 'edit':
        if (isVirtualUser) {
          _navigateToEditVirtualUser(member);
        }
        break;
      case 'make_admin':
        if (!isVirtualUser) {
          _makeAdmin(member, memberProvider);
        }
        break;
      case 'remove_admin':
        if (!isVirtualUser) {
          _removeAdmin(member, memberProvider);
        }
        break;
      case 'unapprove':
        if (!isVirtualUser) {
          _showUnapproveConfirmation(member);
        }
        break;
      case 'remove':
        if (isVirtualUser) {
          _showDeleteVirtualUserConfirmation(member);
        } else {
          _showRemoveConfirmation(member);
        }
        break;
    }
  }
  // Alternative: Pass provider via constructor

  // In member_profile_screen.dart:

  void _navigateToEditVirtualUser(UserModel member) async {
    final virtualUserProvider = context.read<VirtualUserProvider>();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          // CHANGED HERE
          value: virtualUserProvider,
          child: EditVirtualUserScreen(virtualUser: member),
        ),
      ),
    );

    if (result == true && mounted) {
      _refreshMemberData();
    }
  }

  // Member Information Card
  Widget _buildMemberInfoCard(
    UserModel member,
    bool canSeeDetails,
    bool isAdmin,
    bool isVirtualUser,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: AppColors.primary(context),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isVirtualUser
                    ? 'Virtual Member Information'
                    : 'Member Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInfoItem(
            'Email',
            member.email ?? 'Not provided',
            Icons.email_outlined,
          ),
          _buildInfoItem(
            'Phone',
            member.phoneNumber ?? 'Not provided',
            Icons.phone_outlined,
          ), // This will show call icon
          _buildInfoItem(
            'Role',
            isVirtualUser
                ? 'VIRTUAL MEMBER'
                : (member.role.toUpperCase() ?? 'MEMBER'),
            isVirtualUser ? Icons.person_outline : Icons.verified_user_outlined,
          ),
          _buildInfoItem(
            'Status',
            member.isApproved ? 'Approved' : 'Pending',
            Icons.check_circle_outlined,
          ),
          _buildInfoItem(
            'Joined',
            _formatDateFromTimestamp(member.createdAt),
            Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  // Add this new method to create phone info with call icon
  Widget _buildPhoneInfoItem(UserModel member) {
    final phoneNumber = member.phoneNumber;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phone_outlined,
            size: 18,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                if (phoneNumber != null && phoneNumber.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phoneNumber,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.phone_outlined,
                          size: 18,
                          color: AppColors.primary(context),
                        ),
                        onPressed: () => _makePhoneCall(phoneNumber),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Call',
                      ),
                    ],
                  )
                else
                  Text(
                    'Not provided',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Participation History Card
  Widget _buildParticipationHistoryCard(MemberProvider memberProvider) {
    final participationHistory = memberProvider.memberParticipationHistory;
    final loadingHistory = memberProvider.loadingMemberHistory;

    final totalParticipations = participationHistory.length;
    final paidParticipations = participationHistory
        .where((p) => p['hasPaidContribution'] == true)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 10),
              Text(
                'event Participation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  '$totalParticipations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildStatBadge(
                'Paid',
                paidParticipations.toString(),
                AppColors.primary(context),
              ),
              const SizedBox(width: 8),
              _buildStatBadge(
                'Pending',
                (totalParticipations - paidParticipations).toString(),
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (loadingHistory)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                    AppColors.primary(context),
                  ),
                ),
              ),
            )
          else if (participationHistory.isEmpty)
            _buildEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No event Participations',
              message: 'This member hasn\'t joined any events yet.',
            )
          else
            ...participationHistory
                .take(3)
                .map((participation) => _buildParticipationItem(participation)),

          if (participationHistory.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Text(
                    '+ ${participationHistory.length - 3} more events',
                    style: TextStyle(
                      color: AppColors.primary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Participation Item
  Widget _buildParticipationItem(Map<String, dynamic> participation) {
    final EventTitle = participation['EventTitle'] ?? 'Unnnamed event';
    final eventType = participation['eventType'] ?? EventTypes.general;
    final joinedAt =
        (participation['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final hasPaid = participation['hasPaidContribution'] ?? false;
    final contributionPaid = (participation['contributionPaid'] ?? 0)
        .toDouble();
    final suggestedContribution = (participation['suggestedContribution'] ?? 0)
        .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  EventTypes.getIconData(eventType),
                  color: AppColors.primary(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      EventTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(joinedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.category_outlined,
                          size: 12,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          EventTypes.getDisplayName(eventType),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasPaid
                      ? AppColors.primary(context).withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasPaid ? AppColors.primary(context) : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Text(
                  hasPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasPaid ? AppColors.primary(context) : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          if (suggestedContribution > 0) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Contribution',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    Text(
                      '₹${contributionPaid.toStringAsFixed(0)} / ₹${suggestedContribution.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: hasPaid ? AppColors.primary(context) : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: suggestedContribution > 0
                        ? (contributionPaid / suggestedContribution).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.0,
                    backgroundColor: AppColors.progressBackground(context),
                    color: hasPaid ? AppColors.primary(context) : Colors.orange,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(suggestedContribution > 0 ? (contributionPaid / suggestedContribution) * 100 : 0).toStringAsFixed(0)}% ${hasPaid ? 'Completed' : 'Progress'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Contribution Item
  Widget _buildContributionItem(Map<String, dynamic> contribution) {
    final EventTitle = contribution['EventTitle'] ?? 'Unknown event';
    final amount = (contribution['amount'] ?? 0).toDouble();
    final paymentMethod = contribution['paymentMethod'] ?? 'cash';
    final paidAt =
        (contribution['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final eventType = contribution['eventType'] ?? EventTypes.general;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              EventTypes.getIconData(eventType),
              color: AppColors.primary(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EventTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(paidAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPaymentMethodChip(paymentMethod),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Contribution History Card
  Widget _buildContributionHistoryCard(MemberProvider memberProvider) {
    final contributionHistory = memberProvider.memberContributionHistory;
    final loadingHistory = memberProvider.loadingMemberHistory;

    final totalContributions = contributionHistory.length;
    final totalAmount = contributionHistory.fold(
      0.0,
      (sum, c) => sum + (c['amount'] ?? 0.0),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments, color: AppColors.primary(context), size: 22),
              const SizedBox(width: 10),
              Text(
                'Contribution History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  '₹${totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildStatBadge(
                'Total',
                totalContributions.toString(),
                AppColors.primary(context),
              ),
              const SizedBox(width: 8),
              _buildStatBadge(
                'Amount',
                '₹${totalAmount.toStringAsFixed(0)}',
                AppColors.primary(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (loadingHistory)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                    AppColors.primary(context),
                  ),
                ),
              ),
            )
          else if (contributionHistory.isEmpty)
            _buildEmptyState(
              icon: Icons.payments_outlined,
              title: 'No Contributions',
              message: 'This member hasn\'t made any contributions yet.',
            )
          else
            ...contributionHistory
                .take(3)
                .map((contribution) => _buildContributionItem(contribution)),

          if (contributionHistory.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Text(
                    '+ ${contributionHistory.length - 3} more contributions',
                    style: TextStyle(
                      color: AppColors.primary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Privacy Notice
  Widget _buildPrivacyNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary(context).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: AppColors.primary(context), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This member has chosen to keep their detailed information private. '
              'You can only see their basic profile information.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    final isPhone =
        label.toLowerCase() == 'phone' && value.toLowerCase() != 'not provided';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPhone) ...[
                      InkWell(
                        onTap: () => _makePhoneCall(value),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.phone_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _openWhatsApp(value),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: FaIcon(
                            FontAwesomeIcons.whatsapp,
                            size: 18,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    // remove spaces, +, dashes
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    final uri = Uri.parse('https://wa.me/$cleanPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
    } else {
      // optional: show snackbar / toast
      debugPrint('WhatsApp not installed or cannot launch');
    }
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String paymentMethod) {
    final icon = _getPaymentMethodIcon(paymentMethod);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.border(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.textSecondary(context)),
          const SizedBox(width: 4),
          Text(
            paymentMethod.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: AppColors.textSecondary(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Admin Action Methods
  void _makeAdmin(UserModel member, MemberProvider memberProvider) async {
    // 1. Optimistic local update
    if (mounted) {
      setState(() {
        _currentMember = _currentMember?.copyWith(isAdmin: true, role: 'admin');
      });
    }

    final success = await memberProvider.updateMemberRole(member.uid, true);
    if (!mounted) return;

    if (success) {
      SnackbarHelper.showSuccess(
        context,
        '${member.displayName} is now an Admin',
      );
      _refreshMemberDataSilent();
    } else {
      // Revert if failed
      _refreshMemberDataSilent();
    }
  }

  void _removeAdmin(UserModel member, MemberProvider memberProvider) async {
    // 1. Optimistic local update
    if (mounted) {
      setState(() {
        _currentMember = _currentMember?.copyWith(isAdmin: false, role: 'member');
      });
    }

    final success = await memberProvider.updateMemberRole(member.uid, false);
    if (!mounted) return;

    if (success) {
      SnackbarHelper.showSuccess(
        context,
        '${member.displayName} is no longer an Admin',
      );
      _refreshMemberDataSilent();
    } else {
      // Revert if failed
      _refreshMemberDataSilent();
    }
  }

  void _showUnapproveConfirmation(UserModel member) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Unapprove User?',
      message: 'Are you sure you want to unapprove ${member.displayName}? They will no longer be visible in the members list but can be re-approved later.',
      confirmLabel: 'Unapprove',
      isDestructive: true,
    );

    if (result == true) {
      _unapproveUser(member);
    }
  }

  void _unapproveUser(UserModel member) async {
    try {
      final memberProvider = context.read<MemberProvider>();
      final success = await memberProvider.unapproveUser(member.uid);
      if (!mounted) return;

      if (success && mounted) {
        SnackbarHelper.showSuccess(
          context,
          '${member.displayName} has been unapproved',
        );
        _navigateToMembersList();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to unapprove user: $e');
      }
    }
  }

  void _showRemoveConfirmation(UserModel member) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Remove from Community?',
      message: 'Are you sure you want to remove ${member.displayName} from the community? This will completely revoke their access.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (result == true) {
      _removeFromCommunity(member);
    }
  }

  void _showDeleteVirtualUserConfirmation(UserModel member) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Delete Virtual User?',
      message: 'Are you sure you want to delete virtual user "${member.displayName}"? This action cannot be undone and will erase all data.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (result == true) {
      _deleteVirtualUser(member);
    }
  }

  void _removeFromCommunity(UserModel member) async {
    try {
      final memberProvider = context.read<MemberProvider>();
      final success = await memberProvider.removeFromCommunity(member.uid);
      if (!mounted) return;

      if (success && mounted) {
        SnackbarHelper.showSuccess(
          context,
          '${member.displayName} has been removed from community',
        );
        _navigateToMembersList();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to remove user: $e');
      }
    }
  }

  void _deleteVirtualUser(UserModel member) async {
    try {
      final memberProvider = context.read<MemberProvider>();
      // You need to implement deleteVirtualUser in MemberProvider
      final success = await memberProvider.deleteVirtualUser(member.uid);
      if (!mounted) return;

      if (success && mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Virtual user ${member.displayName} has been deleted',
        );
        _navigateToMembersList();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to delete virtual user: $e');
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleanedNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid phone number'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final url = Uri.parse('tel:$cleanedNumber');

      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        if (!mounted) return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot make calls from this device'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToMembersList() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.allMembers,
      (route) => false,
    );
  }

  // Helper Methods
  String _formatDateFromTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${_getDay(date.day)} ${_getMonth(date.month)} ${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${_getDay(date.day)} ${_getMonth(date.month)} ${date.year}';
  }

  String _getDay(int day) {
    return day.toString().padLeft(2, '0');
  }

  String _getMonth(int month) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  IconData _getPaymentMethodIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'upi':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }
}





