import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';
import './tabs/dashboard_tab.dart';
import './tabs/programs_tab.dart';
import './tabs/history_tab.dart';
import './tabs/members_tab.dart';
import './tabs/profile_tab.dart';
import 'package:kofund/ads/simple_banner_ad.dart'; // Add this import
class CommunityDashboard extends StatefulWidget {
  const CommunityDashboard({super.key});

  @override
  State<CommunityDashboard> createState() => _CommunityDashboardState();
}

class _CommunityDashboardState extends State<CommunityDashboard> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const ProgramsTab(),
    const HistoryTab(),
    const MembersTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Main content - takes most of the space
          Expanded(
            child: _tabs[_currentIndex],
          ),
          
          // Banner ad at the bottom
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

  // Bottom Navigation Bar
  Widget _buildBottomNavigationBar(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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