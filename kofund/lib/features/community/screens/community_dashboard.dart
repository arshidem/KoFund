// lib/features/community/screens/community_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/ads/simple_banner_ad.dart';
import 'package:kofund/routing/route_names.dart';
import './tabs/dashboard_tab.dart';
import './tabs/programs_tab.dart';
import './tabs/history_tab.dart';
import './tabs/members_tab.dart';
import './tabs/profile_tab.dart';
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

  final List<Widget> _tabs = [
    const DashboardTab(),
    const ProgramsTab(),
    const HistoryTab(),
    const MembersTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
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
    return Scaffold(
      body: Column(
        children: [
          // Main content
          Expanded(
            child: _tabs[_currentIndex],
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
      bottomNavigationBar: _buildBottomNavigationBar(isDarkMode),
    );
  }

  // Bottom Navigation Bar (unchanged)
  Widget _buildBottomNavigationBar(bool isDarkMode) {
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
          setState(() {
            _currentIndex = index;
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Programs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outlined),
            activeIcon: Icon(Icons.people),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
