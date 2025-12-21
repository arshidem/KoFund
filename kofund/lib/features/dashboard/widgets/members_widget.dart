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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: MembersWidget initState called');
    
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
      print('👤 DEBUG: User/Community actually changed in MembersWidget');
      print('   Previous user: $_currentUserId, community: $_currentCommunityId');
      print('   New user: $newUserId, community: $newCommunityId');
      
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
    print('👤 DEBUG: User logged out, clearing MembersWidget');
    
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
    
    print('🔄 DEBUG: Resetting MembersWidget for new user/community');
    
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
      print('❌ DEBUG: No user found in MembersWidget');
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
    
    // Call the method without await (since it returns void)
    memberProvider.refreshForUser(communityId);
    
    // If you need to wait for it to complete, check if there's a different method
    // For example, if there's a loadMembers or fetchMembers method:
    // await memberProvider.loadMembers(communityId);
    
    // Or use a small delay to allow the provider to update
    await Future.delayed(const Duration(milliseconds: 100));
    
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
        const SizedBox(height: 6),
        
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
          padding: const EdgeInsets.all(2),
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
  // Determine which contact info to display
  final String contactInfo;
  if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty) {
    contactInfo = member.phoneNumber!;
  } else if (member.email != null && member.email!.isNotEmpty) {
    contactInfo = member.email!;
  } else {
    contactInfo = 'No contact info';
  }

  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Add onTap functionality if needed
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar/Initials
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary(context).withOpacity(0.12),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(member.displayName ?? member.email ?? '?'),
                      style: TextStyle(
                        color: AppColors.primary(context),
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
                      Row(
                        children: [
                          Text(
                            member.displayName ?? 'Unnamed Member',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          if (member.isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contactInfo,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Chevron icon
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary(context),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
      
      // Horizontal divider
      Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border(context),
        indent: 16,
        endIndent: 16,
      ),
    ],
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