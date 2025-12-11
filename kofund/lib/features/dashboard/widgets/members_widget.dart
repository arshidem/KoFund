// lib/features/dashboard/widgets/members_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/members/providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/members/screens/all_members_screen.dart';

class MembersWidget extends StatefulWidget {
  const MembersWidget({
    super.key,
  });

  @override
  State<MembersWidget> createState() => _MembersWidgetState();
}

class _MembersWidgetState extends State<MembersWidget> {
  String? _currentUserId;
  String? _currentCommunityId;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: MembersWidget initState called');
    
    // Initial load after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Listen for auth changes
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    // Check if user has changed OR community has changed
    if (user?.uid != _currentUserId || user?.communityId != _currentCommunityId) {
      print('👤 DEBUG: User/Community changed in MembersWidget');
      print('   Previous user: $_currentUserId, community: $_currentCommunityId');
      print('   New user: ${user?.uid}, community: ${user?.communityId}');
      
      _currentUserId = user?.uid;
      _currentCommunityId = user?.communityId;
      
      // Reset state for new user/community
      _resetForNewUser();
    }
  }

  void _resetForNewUser() {
    print('🔄 DEBUG: Resetting MembersWidget for new user/community');
    
    // Reset the MemberProvider data
    final memberProvider = context.read<MemberProvider>();
    memberProvider.clearDataForUserChange();
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }
    
    // Load data for new user
    _checkAuthAndLoadData();
  }

  void _checkAuthAndLoadData() {
    if (!mounted) return;
    
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    final memberProvider = context.read<MemberProvider>();
    
    if (user == null) {
      print('❌ DEBUG: No user found in MembersWidget');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Please sign in to view members';
        });
      }
      
      // Clear provider data when no user
      memberProvider.clearDataForUserChange();
      return;
    }
    
    // Check if user has community
    if (user.communityId == null || user.communityId!.isEmpty) {
      print('❌ DEBUG: User has no community');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'You are not part of any community';
        });
      }
      return;
    }
    
    print('✅ DEBUG: User found with community ${user.communityId}, loading members...');
    _loadMembersData(user.communityId!);
  }

  void _loadMembersData(String communityId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      final memberProvider = context.read<MemberProvider>();
      
      // Refresh provider for the new community
      memberProvider.refreshForUser(communityId);
      
      // Wait a moment for the provider to start loading
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('❌ DEBUG: Error loading members data: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load members: $error';
        });
      }
    }
  }

  void _retryLoading() {
    _checkAuthAndLoadData();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final user = authProvider.user;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "Members" and "See all"
        _buildHeaderSection(context, user),
        const SizedBox(height: 16),
        
        // Members list with proper user context
        _buildMembersContent(user),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, UserModel? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Members",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        TextButton(
          onPressed: user != null ? () => _navigateToAllMembers(context) : null,
          style: TextButton.styleFrom(
            foregroundColor: user != null ? AppColors.primary(context) : AppColors.textSecondary(context),
          ),
          child: const Text("See all"),
        ),
      ],
    );
  }

  void _navigateToAllMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllMembersScreen(),
      ),
    );
  }

  Widget _buildMembersContent(UserModel? user) {
    // If no user is logged in
    if (user == null) {
      return _buildNoUserState(context);
    }
    
    // If user has no community
    if (user.communityId == null || user.communityId!.isEmpty) {
      return _buildNoCommunityState(context);
    }
    
    // If loading
    if (_isLoading) {
      return _buildLoadingState(context);
    }
    
    // If error
    if (_hasError) {
      return _buildErrorState(context);
    }
    
    // Show members from provider
    return Consumer<MemberProvider>(
      builder: (context, memberProvider, child) {
        final members = memberProvider.members;
        
        // Debug: Print current members
        print('📊 MembersWidget: Showing ${members.length} members');
        if (members.isNotEmpty) {
          print('   First member: ${members.first.displayName} (UID: ${members.first.uid})');
          print('   First member community: ${members.first.communityId}');
        }
        
        // If no members
        if (members.isEmpty) {
          return _buildNoMembersState(context);
        }

        // Show first 3-4 members
        final displayMembers = members.take(4).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ...displayMembers.map((member) => _buildMemberItem(
                member: member,
                context: context,
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoUserState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_outline,
            size: 48,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            "Sign in to View Members",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please sign in to see community members",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCommunityState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_outlined,
            size: 48,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            "No Community",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Join a community to view members",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem({
    required UserModel member,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar/Initials
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(member.displayName ?? member.email ?? '?'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Member details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName ?? 'Unnamed Member',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.email ?? 'No email',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.phoneNumber!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Admin badge (optional)
          if (member.isAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning(context).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Admin',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
          ),
          const SizedBox(width: 16),
          Text(
            "Loading members...",
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: AppColors.error(context),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Failed to load members',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.error(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _retryLoading,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMembersState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            "No Members Found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Members will appear here once they join and get approved",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return '?';
  }
}