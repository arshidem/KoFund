// lib/features/members/screens/member_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/skeleton/member_details_skeleton.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/routing/route_names.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:kofund/core/services/contribution_service.dart';
import 'package:kofund/core/services/virtual_user_service.dart';
// =================== MAIN SCREEN ===================
class MemberDetailsScreen extends StatelessWidget {
  final UserModel? member;
  
  const MemberDetailsScreen({
    super.key,
    this.member,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    return ChangeNotifierProvider(
      create: (_) => MemberProvider(
        userService: UserService(),
        authProvider: auth,
        participantService: ParticipantService(),
        contributionService: ContributionService(),
        virtualUserService: VirtualUserService(), // Add this
      ),
      child: _MemberDetailsScreenBody(member: member),
    );
  }
}

// =================== SCREEN BODY ===================
class _MemberDetailsScreenBody extends StatefulWidget {
  final UserModel? member;
  
  const _MemberDetailsScreenBody({
    Key? key,
    this.member,
  });

  @override
  State<_MemberDetailsScreenBody> createState() => _MemberDetailsScreenBodyState();
}

// =================== SCREEN STATE ===================
class _MemberDetailsScreenBodyState extends State<_MemberDetailsScreenBody> {
  UserModel? _currentMember;
  bool _isLoading = false;
  final RefreshController _refreshController = RefreshController();
  
  // Track current user to detect changes
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: MemberDetailsScreen initState called');
    _loadMemberData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if current user has changed (logout/login scenario)
    final authProvider = context.read<AppAuthProvider>();
    final currentUser = authProvider.user;
    
    if (currentUser?.uid != _currentUserId) {
      print('👤 DEBUG: User changed in MemberDetailsScreen - from $_currentUserId to ${currentUser?.uid}');
      _currentUserId = currentUser?.uid;
      
      // Reset screen state for new user
      _resetScreenForNewUser();
    }
  }

  void _resetScreenForNewUser() {
    if (!mounted) return;
    
    print('🔄 DEBUG: Resetting MemberDetailsScreen for new user');
    
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
          
          final freshMember = await memberProvider.getMemberById(selectedMember.uid);
          if (freshMember != null) {
            _currentMember = freshMember;
          }
        }
      }
      
      // Load history if admin or member has detailed profile
      if (_currentMember != null) {
        final currentUser = context.read<AppAuthProvider>().user;
        final isAdmin = currentUser?.isAdmin == true;
        final shouldLoadHistory = isAdmin || _currentMember!.showDetailedProfile;
        
        if (shouldLoadHistory) {
          await _loadMemberHistory();
        }
      }
    } catch (e) {
      print('❌ DEBUG: Error loading member data: $e');
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
      
      if (_currentMember != null) {
        final memberProvider = context.read<MemberProvider>();
        final freshMember = await memberProvider.getMemberById(_currentMember!.uid);
        if (freshMember != null) {
          setState(() {
            _currentMember = freshMember;
          });
        }
        
        // Load history if admin or member has detailed profile
        final currentUser = context.read<AppAuthProvider>().user;
        final isAdmin = currentUser?.isAdmin == true;
        final shouldLoadHistory = isAdmin || _currentMember!.showDetailedProfile;
        
        if (shouldLoadHistory) {
          await memberProvider.loadMemberHistoryData(_currentMember!.uid);
        }
      }
      
      _refreshController.refreshCompleted();
    } catch (e) {
      print('❌ DEBUG: Error refreshing member data: $e');
      _refreshController.refreshFailed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onRefresh() async {
    await _refreshMemberData();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AppAuthProvider>().user;
    final memberProvider = context.watch<MemberProvider>();
    final member = _currentMember;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: MemberDetailsSkeleton(),
      );
    }

    if (member == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: const Text(
            'Member Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),
        ),
        body: Center(
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
                'Member not found',
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final isAdmin = currentUser?.isAdmin == true;
    final canSeeDetails = isAdmin || member.showDetailedProfile;
    final isVirtualUser = member.isVirtualUser;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Text(
          'Member Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            size: 24,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        enablePullDown: true,
        enablePullUp: false,
        physics: const BouncingScrollPhysics(),
        header: ClassicHeader(
          idleText: 'Pull down to refresh',
          releaseText: 'Release to refresh',
          refreshingText: 'Refreshing...',
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Profile Header Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildProfileHeaderCard(member, isAdmin, isVirtualUser),
              ),

              // Virtual User Info Card (if virtual user)
              if (isVirtualUser)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildVirtualUserInfoCard(member),
                ),

              // Member Information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMemberInfoCard(member, canSeeDetails, isAdmin, isVirtualUser),
              ),
              const SizedBox(height: 16),

              // Participation History (Only if detailed profile enabled and not virtual user)
              if (canSeeDetails && !isVirtualUser) 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildParticipationHistoryCard(memberProvider),
                ),
              
              // Contribution History (Only if detailed profile enabled and not virtual user)
              if (canSeeDetails && !isVirtualUser) 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: _buildContributionHistoryCard(memberProvider),
                ),

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
      ),
    );
  }

  // Profile Header Card (Horizontal Rectangle)
  Widget _buildProfileHeaderCard(UserModel member, bool isAdmin, bool isVirtualUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isVirtualUser 
            ? LinearGradient(
                colors: [Colors.purple[800]!, Colors.purple[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.primaryGradient(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isVirtualUser ? Colors.purple : AppColors.primary(context)).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 1),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: isVirtualUser ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3), 
                    width: 2
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        member.displayName?.substring(0, 1).toUpperCase() ?? '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isVirtualUser)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.purple[800],
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
                        if (isVirtualUser)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'VIRTUAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    Row(
                      children: [
                        Icon(Icons.email, size: 16, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            member.email ?? 'No email',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.white.withOpacity(0.8)),
                          const SizedBox(width: 8),
                          Text(
                            member.phoneNumber!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(
                              Icons.phone_outlined,
                              size: 20,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            onPressed: () => _makePhoneCall(member.phoneNumber!),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          // Three-dot menu (only for admins viewing other members)
          if (isAdmin && member.uid != context.read<AppAuthProvider>().user?.uid)
            Positioned(
              top: -8,
              right: -10,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.8)),
                onSelected: (value) => _handleMenuAction(value, member, isVirtualUser),
                itemBuilder: (context) {
                  if (isVirtualUser) {
                    // Virtual user menu - only "Remove from Community"
                    return [
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remove from Community'),
                          ],
                        ),
                      ),
                    ];
                  } else {
                    // Regular user menu
                    return [
                      if (!member.isAdmin)
                        const PopupMenuItem<String>(
                          value: 'make_admin',
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, size: 20, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Make Admin'),
                            ],
                          ),
                        ),
                      if (member.isAdmin)
                        const PopupMenuItem<String>(
                          value: 'remove_admin',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove, size: 20, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Remove Admin'),
                            ],
                          ),
                        ),
                      const PopupMenuItem<String>(
                        value: 'unapprove',
                        child: Row(
                          children: [
                            Icon(Icons.block, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Unapprove User'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remove from Community'),
                          ],
                        ),
                      ),
                    ];
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  // Virtual User Info Card
  Widget _buildVirtualUserInfoCard(UserModel member) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.purple, size: 22),
              const SizedBox(width: 10),
              Text(
                'Virtual Member Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (member.createdBy != null && member.createdBy!.isNotEmpty) ...[
            _buildVirtualInfoItem('Created By Admin', member.createdBy!, Icons.person_add),
            const SizedBox(height: 12),
          ],
          
          if (member.createdAt != null) ...[
            _buildVirtualInfoItem('Created On', _formatDateFromTimestamp(member.createdAt), Icons.calendar_today),
            const SizedBox(height: 12),
          ],
          
          // Note about virtual users
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info, size: 18, color: Colors.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Virtual members don\'t have app access. They are managed by community admins.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.purple[800],
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
        Icon(icon, size: 18, color: Colors.purple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.purple[800],
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

  // Member Information Card
  Widget _buildMemberInfoCard(UserModel member, bool canSeeDetails, bool isAdmin, bool isVirtualUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                isVirtualUser ? Icons.person_outline : Icons.person_outline,
                color: isVirtualUser ? Colors.purple : AppColors.primary(context),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isVirtualUser ? 'Virtual Member Information' : 'Member Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isVirtualUser ? Colors.purple[800] : AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoItem('Email', member.email ?? 'Not provided', Icons.email_outlined),
          _buildInfoItem('Role', isVirtualUser ? 'VIRTUAL MEMBER' : (member.role?.toUpperCase() ?? 'MEMBER'), 
              isVirtualUser ? Icons.person_outline : Icons.verified_user_outlined),
          _buildInfoItem('Status', member.isApproved ? 'Approved' : 'Pending', Icons.check_circle_outline),
          _buildInfoItem('Joined', _formatDateFromTimestamp(member.createdAt), Icons.calendar_today_outlined),
          
          if (canSeeDetails || isVirtualUser) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.border(context)),
            const SizedBox(height: 12),
            _buildInfoItem('Phone', member.phoneNumber ?? 'Not provided', Icons.phone_outlined),
            _buildInfoItem('Community', member.communityName ?? 'Not set', Icons.group_outlined),
          ],
          
          if (isAdmin) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.border(context)),
            const SizedBox(height: 12),
            Text(
              'Admin View',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary(context),
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoItem('User ID', member.uid.substring(0, 8) + '...', Icons.fingerprint_outlined),
            if (!isVirtualUser)
              _buildInfoItem('Privacy', member.showDetailedProfile ? 'Detailed Profile' : 'Basic Profile', Icons.visibility_outlined),
          ],
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
        .where((p) => p['hasPaidContribution'] == true).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                'Program Participation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
              _buildStatBadge('Paid', paidParticipations.toString(), Colors.green),
              const SizedBox(width: 8),
              _buildStatBadge('Pending', (totalParticipations - paidParticipations).toString(), Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          
          if (loadingHistory)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
                ),
              ),
            )
          else if (participationHistory.isEmpty)
            _buildEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No Program Participations',
              message: 'This member hasn\'t joined any programs yet.',
            )
          else
            ...participationHistory.take(3).map((participation) => 
              _buildParticipationItem(participation)
            ),
          
          if (participationHistory.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+ ${participationHistory.length - 3} more programs',
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
    final programTitle = participation['programTitle'] ?? 'Unnamed Program';
    final programType = participation['programType'] ?? ProgramTypes.general;
    final joinedAt = (participation['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final hasPaid = participation['hasPaidContribution'] ?? false;
    final contributionPaid = (participation['contributionPaid'] ?? 0).toDouble();
    final suggestedContribution = (participation['suggestedContribution'] ?? 0).toDouble();

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
                  color: AppColors.primary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ProgramTypes.getIconData(programType),
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
                      programTitle,
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
                        Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary(context)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(joinedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.category_outlined, size: 12, color: AppColors.textSecondary(context)),
                        const SizedBox(width: 4),
                        Text(
                          ProgramTypes.getDisplayName(programType),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasPaid ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Text(
                  hasPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasPaid ? Colors.green : Colors.orange,
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
                        color: hasPaid ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: suggestedContribution > 0 ? (contributionPaid / suggestedContribution).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: AppColors.progressBackground(context),
                    color: hasPaid ? Colors.green : Colors.orange,
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
    final programTitle = contribution['programTitle'] ?? 'Unknown Program';
    final amount = (contribution['amount'] ?? 0).toDouble();
    final paymentMethod = contribution['paymentMethod'] ?? 'cash';
    final paidAt = (contribution['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final programType = contribution['programType'] ?? ProgramTypes.general;

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
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ProgramTypes.getIconData(programType),
              color: Colors.green,
              size: 20,
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
                    Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary(context)),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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
    final totalAmount = contributionHistory
        .fold(0.0, (sum, c) => sum + (c['amount'] ?? 0.0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(Icons.payments, color: Colors.green, size: 22),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              _buildStatBadge('Total', totalContributions.toString(), AppColors.primary(context)),
              const SizedBox(width: 8),
              _buildStatBadge('Amount', '₹${totalAmount.toStringAsFixed(0)}', Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          
          if (loadingHistory)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
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
            ...contributionHistory.take(3).map((contribution) => 
              _buildContributionItem(contribution)
            ),
          
          if (contributionHistory.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+ ${contributionHistory.length - 3} more contributions',
                    style: const TextStyle(
                      color: Colors.green,
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
        border: Border.all(color: AppColors.primary(context).withOpacity(0.3)),
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

  // Helper Widgets
  Widget _buildInfoItem(String label, String value, IconData icon) {
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
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
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

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary(context).withOpacity(0.5)),
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
    );
  }

  // Admin Action Methods
  void _makeAdmin(UserModel member, MemberProvider memberProvider) async {
    final success = await memberProvider.updateMemberRole(member.uid, true);
    
    if (success && mounted) {
      SnackbarHelper.showSuccess(context, '${member.displayName} is now an Admin');
      _refreshMemberData();
    }
  }

  void _removeAdmin(UserModel member, MemberProvider memberProvider) async {
    final success = await memberProvider.updateMemberRole(member.uid, false);
    
    if (success && mounted) {
      SnackbarHelper.showSuccess(context, '${member.displayName} is no longer an Admin');
      _refreshMemberData();
    }
  }

  void _showUnapproveConfirmation(UserModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unapprove User?',
          style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to unapprove ${member.displayName}? '
          'They will no longer be visible in the members list but can be re-approved later.',
          style: TextStyle(color: AppColors.textSecondary(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unapproveUser(member);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unapprove'),
          ),
        ],
      ),
    );
  }

  void _unapproveUser(UserModel member) async {
    try {
      final memberProvider = context.read<MemberProvider>();
      final success = await memberProvider.unapproveUser(member.uid);
      
      if (success && mounted) {
        SnackbarHelper.showSuccess(context, '${member.displayName} has been unapproved');
        _navigateToMembersList();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to unapprove user: $e');
      }
    }
  }

  void _showRemoveConfirmation(UserModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove from Community?',
          style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove ${member.displayName} from the community? '
          'This will remove their community access completely.',
          style: TextStyle(color: AppColors.textSecondary(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFromCommunity(member);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showDeleteVirtualUserConfirmation(UserModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Virtual User?',
          style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete virtual user "${member.displayName}"? '
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVirtualUser(member);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _removeFromCommunity(UserModel member) async {
    try {
      final memberProvider = context.read<MemberProvider>();
      final success = await memberProvider.removeFromCommunity(member.uid);
      
      if (success && mounted) {
        SnackbarHelper.showSuccess(context, '${member.displayName} has been removed from community');
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
      
      if (success && mounted) {
        SnackbarHelper.showSuccess(context, 'Virtual user ${member.displayName} has been deleted');
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
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  IconData _getPaymentMethodIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'online':
        return Icons.payment;
      case 'upi':
        return Icons.phone_android;
      case 'card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }
}