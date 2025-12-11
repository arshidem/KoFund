// lib/features/programs/screens/program_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/ads/simple_banner_ad.dart'; // Add this import

import '../models/program_model.dart';
import '../providers/program_provider.dart';
import 'tabs/program_overview_tab.dart';
import 'tabs/program_participants_tab.dart';
import 'tabs/program_contributions_tab.dart';
import 'tabs/program_expenses_tab.dart';
import 'tabs/program_analytics_tab.dart';

class ProgramDetailsScreen extends StatefulWidget {
  final String programId;

  const ProgramDetailsScreen({super.key, required this.programId});

  @override
  State<ProgramDetailsScreen> createState() => _ProgramDetailsScreenState();
}

class _ProgramDetailsScreenState extends State<ProgramDetailsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabTitles = [
    'Overview',
    'Participants',
    'Contributions',
    'Expenses',
    'Analytics'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Details'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
            ),
          ),
        ),
      ),
      body: StreamBuilder<ProgramModel?>(
        stream: programProvider.getProgramById(widget.programId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Program not found.'));
          }

          final program = snapshot.data!;

          return Column(
            children: [
              // Main content area with tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Overview
                    ProgramOverviewTab(program: program),
                    
                    // Tab 2: Participants
                    ProgramParticipantsTab(program: program),
                    
                    // Tab 3: Contributions
                    ProgramContributionsTab(program: program),
                    
                    // Tab 4: Expenses
                    ProgramExpensesTab(program: program),
                    
                    // Tab 5: Analytics
                    ProgramAnalyticsTab(program: program),
                  ],
                ),
              ),
              
              // 🔥 BANNER AD AT THE BOTTOM (Shows on ALL tabs)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: const SimpleBannerAd(),
              ),
            ],
          );
        },
      ),
    );
  }
}