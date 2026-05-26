// lib/features/community/screens/community_dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/ads/simple_banner_ad.dart';
import 'package:kofund/routing/route_names.dart';
import './tabs/dashboard_tab.dart';
import './tabs/events_tab.dart';

import './tabs/members_tab.dart';
import './tabs/profile_tab.dart';
import 'package:kofund/features/admin/providers/user_provider.dart';
// Import your skeleton
import 'package:kofund/core/skeleton/dashboard_skeleton.dart';



class CommunityDashboard extends StatefulWidget {
  const CommunityDashboard({super.key});

  @override
  State<CommunityDashboard> createState() => _CommunityDashboardState();
}

class _CommunityDashboardState extends State<CommunityDashboard> {
  int _currentIndex = 0;
  bool _isCheckingAuth = true;
  bool _forceMembersBackButton = false;
  late PageController _pageController;

  void _navigateToEvents() {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToMembers() {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  List<Widget> get _tabs => [
    DashboardTab(key: const PageStorageKey('dashboard'), onNavigateToMembers: _navigateToMembers, onNavigateToEvents: _navigateToEvents),
    const EventsTab(key: PageStorageKey('events')),
    const MembersTab(key: PageStorageKey('members')),
    const ProfileTab(key: PageStorageKey('profile')),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Add a small delay to ensure context is available
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 🧩 1️⃣ Show Skeleton while checking auth status
    if (_isCheckingAuth) {
      return DashboardSkeleton(isDarkMode: isDarkMode);
    }

    // 🧩 2️⃣ If the user is logged out
    if (authProvider.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context, 
            RouteNames.login, 
            (route) => false
          );
        }
      });
      return DashboardSkeleton(isDarkMode: isDarkMode);
    }

    // 🧩 3️⃣ If the user hasn't joined a community
    if (authProvider.user?.communityId == null || 
        authProvider.user!.communityId!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context, 
            RouteNames.joinCommunity
          );
        }
      });
      return DashboardSkeleton(isDarkMode: isDarkMode);
    }

    // 🧩 4️⃣ If user is not yet approved
    if (authProvider.user?.isApproved == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context, 
            RouteNames.pendingApproval
          );
        }
      });
      return DashboardSkeleton(isDarkMode: isDarkMode);
    }

    // 🧩 5️⃣ User is authenticated and approved - show dashboard
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldExit = await DialogHelper.showConfirmationDialog(
          context,
          title: 'Exit App?',
          message: 'Are you sure you want to close the app?',
          confirmLabel: 'Exit',
          cancelLabel: 'Stay',
          icon: Icons.exit_to_app_rounded,
          isDestructive: true,
        );

        if (shouldExit == true && context.mounted) {
           // Standard way to close the app on Android
           await SystemChannels.platform.invokeMethod<void>('SystemNavigator.pop', true);
           
           // Fallback for some environments where the above might not respond immediately
           await Future.delayed(const Duration(milliseconds: 200));
           if (context.mounted) {
             exit(0);
           }
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // Main content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentIndex = index;
                    _forceMembersBackButton = false;
                  });
                },
                children: _tabs,
              ),
            ),
            
            // Banner ad
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
              child: const SimpleBannerAd(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(isDarkMode, authProvider),
      ),
    );
  }

  // Bottom Navigation Bar (unchanged)
  Widget _buildBottomNavigationBar(bool isDarkMode, AppAuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          HapticFeedback.selectionClick();
          setState(() {
            _forceMembersBackButton = false;
            _currentIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        selectedItemColor: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
        unselectedItemColor: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                final pendingCount = userProvider.pendingMembers.length;
                final isAdmin = authProvider.user?.isAdmin ?? false;
                
                if (isAdmin && pendingCount > 0) {
                  return Badge(
                    label: Text(pendingCount > 9 ? '9+' : pendingCount.toString()),
                    backgroundColor: AppColors.warning(context),
                    child: const Icon(Icons.people_outlined),
                  );
                }
                return const Icon(Icons.people_outlined);
              },
            ),
            activeIcon: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                final pendingCount = userProvider.pendingMembers.length;
                final isAdmin = authProvider.user?.isAdmin ?? false;
                
                if (isAdmin && pendingCount > 0) {
                  return Badge(
                    label: Text(pendingCount > 9 ? '9+' : pendingCount.toString()),
                    backgroundColor: AppColors.warning(context),
                    child: const Icon(Icons.people),
                  );
                }
                return const Icon(Icons.people);
              },
            ),
            label: 'Members',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}



