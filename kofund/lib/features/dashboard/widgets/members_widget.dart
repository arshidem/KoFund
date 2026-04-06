// lib/features/dashboard/widgets/members_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/features/members/providers/member_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/members/screens/all_members_screen.dart';
import 'package:kofund/features/members/screens/member_details_screen.dart';

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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 DEBUG: MembersWidget initState called');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _isInitialized = true;
        _checkAuthAndLoadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_isInitialized) return;
    
    // Listen for auth changes - but only when actually different
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    final newUserId = user?.uid;
    final newCommunityId = user?.communityId;
    
    // Check if user or community has ACTUALLY changed
    if (newUserId != _currentUserId || newCommunityId != _currentCommunityId) {
      debugPrint('👤 DEBUG: User/Community actually changed in MembersWidget');
      debugPrint('   Previous user: $_currentUserId, community: $_currentCommunityId');
      debugPrint('   New user: $newUserId, community: $newCommunityId');
      
      _currentUserId = newUserId;
      _currentCommunityId = newCommunityId;
      
      // Only reset if we have a new valid user/community
      if (newUserId != null || newCommunityId != null) {
        _resetForNewUser();
      } else if (newUserId == null && _currentUserId != null) {
        // User logged out
        _handleUserLogout();
      }
    }
  }

  void _handleUserLogout() {
    debugPrint('👤 DEBUG: User logged out, clearing MembersWidget');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Please sign in to view members';
        _currentUserId = null;
        _currentCommunityId = null;
      });
    }
  }

  void _resetForNewUser() {
    if (!mounted) return;
    
    debugPrint('🔄 DEBUG: Resetting MembersWidget for new user/community');
    
    // Reset state
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
    
    if (user == null) {
      debugPrint('❌ DEBUG: No user found in MembersWidget');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Please sign in to view members';
        });
      }
      return;
    }
    
    // Check if user has community
    if (user.communityId == null || user.communityId!.isEmpty) {
      debugPrint('❌ DEBUG: User has no community');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'You are not part of any community';
        });
      }
      return;
    }
    
    debugPrint('✅ DEBUG: User found with community ${user.communityId}, loading members...');
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
      
      // Call the method without await (since it returns void)
      memberProvider.refreshForUser(communityId);
      
      // Use a small delay to allow the provider to update
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('❌ DEBUG: Error loading members data: $error');
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
    
    return _buildMembersContent(user);
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
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: 'Sign in to View Members',
        message: 'Please sign in to see community members',
      );
    }
    
    // If user has no community
    if (user.communityId == null || user.communityId!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_outlined,
        title: 'No Community',
        message: 'Join a community to view members',
      );
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
        debugPrint('📊 MembersWidget: Showing ${members.length} members');
        if (members.isNotEmpty) {
          debugPrint('   First member: ${members.first.displayName} (UID: ${members.first.uid})');
          debugPrint('   First member community: ${members.first.communityId}');
        }
        
        // If no members
        if (members.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'No Members Found',
            message: 'Members will appear here once they join and get approved',
          );
        }

        // Show first 3-4 members
        final displayMembers = members.take(4).toList();

        return _buildRecentMembersList(displayMembers, context, user);
      },
    );
  }

  Widget _buildRecentMembersList(List<UserModel> members, BuildContext context, UserModel? user) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with proper padding
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.group_rounded,
                  size: 18,
                  color: AppColors.primary(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Recent Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                if (members.length >= 3 && user != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _navigateToAllMembers(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
SizedBox(height: 4),

          // Members list with proper padding
                MediaQuery.removePadding(
  context: context,
  removeTop: true,
  child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) => Divider(
                height: 2,
                thickness: 0.8,
                color: AppColors.border(context),
              ),
              itemBuilder: (context, index) {
                return _buildMemberListItem(members[index]);
              },
            ),
            
          ),


        ],
      ),
    );
  }

  Widget _buildMemberListItem(UserModel member) {
    final String contactInfo =
        member.phoneNumber?.isNotEmpty == true
            ? member.phoneNumber!
            : member.email.isNotEmpty == true
                ? member.email
                : 'No contact info';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberDetailsScreen(member: member),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              // Avatar container (square, matching history widget)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Center(
                  child: Text(
                    _getInitials(
                      member.displayName ?? member.email ?? '?',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Name + contact (compact layout)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.displayName ?? 'Unnamed Member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contactInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right side: Admin badge and chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Admin badge (compact - matching programs widget)
                  if (member.isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  
                  if (!member.isAdmin) const SizedBox(height: 20),
                ],
              ),

              const SizedBox(width: 6),

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 120,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Skeleton items
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildMemberSkeletonItem(context),
              if (i < 2) 
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSkeletonItem(BuildContext context) {
    return Row(
      children: [
        // Avatar skeleton
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.textTertiary(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
        ),
        const SizedBox(width: 10),
        
        // Text content skeleton
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
              ),
            ],
          ),
        ),
        
        // Badge and chevron skeleton
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 40,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.error(context),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Failed to load members',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error(context),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            onTap: _retryLoading,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.3)),
              ),
              child: Text(
                'Retry',
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

