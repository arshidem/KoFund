import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/program_model.dart';
import '../providers/program_provider.dart';
import '../../../features/participants/providers/participant_provider.dart';
import '../../../features/participants/models/participant_model.dart';
import '../../../features/auth/providers/app_auth_provider.dart';
import 'tabs/program_overview_tab.dart';
import 'tabs/program_participants_tab.dart';
import 'tabs/program_contributions_tab.dart';
import 'tabs/program_expenses_tab.dart';
import 'tabs/program_analytics_tab.dart';
import '../../../../core/constants/app_colors.dart';

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

  // Join program method
  Future<void> _joinProgram(BuildContext context) async {
    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final participantProvider =
          Provider.of<ParticipantProvider>(context, listen: false);
      final programProvider =
          Provider.of<ProgramProvider>(context, listen: false);

      final currentUser = authProvider.user;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please sign in to join the program'),
            backgroundColor: AppColors.error(context),
          ),
        );
        return;
      }

      // Get program data
      final program = await programProvider.getProgramById(widget.programId).first;
      if (program == null) return;

      // Check if program is full
      final participants = await participantProvider
          .streamProgramParticipants(widget.programId)
          .first;
      final participantCount = participants.length;

      final isFull = program.participantType == 'fixed' &&
          participantCount >= program.maxParticipants;

      if (isFull) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Program is full!'),
            backgroundColor: AppColors.error(context),
          ),
        );
        return;
      }

      // Check if user already joined
      final hasJoined = participants.any(
        (p) => p.userId == currentUser.uid && p.status == 'joined',
      );

      if (hasJoined) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have already joined this program'),
            backgroundColor: AppColors.warning(context),
          ),
        );
        return;
      }

      // Create participant model
      final participant = ParticipantModel(
        participantId: '',
        programId: widget.programId,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'User',
        userEmail: currentUser.email ?? '',
        communityId: program.communityId,
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: program.suggestedContribution != null ? 0 : null,
        hasPaidContribution: program.suggestedContribution == null,
      );

      await participantProvider.joinProgram(participant);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined the program!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join program: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

  // Leave program method
  Future<void> _leaveProgram(BuildContext context) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final participantProvider =
        Provider.of<ParticipantProvider>(context, listen: false);

    final currentUser = authProvider.user;
    if (currentUser == null) return;

    // Show confirmation dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Leave Program?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          'Are you sure you want to leave this program? '
          'This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary(context),
            height: 1.5,
          ),
        ),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
          // Leave Button
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Leave Program'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await participantProvider.leaveProgram(widget.programId, currentUser.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left the program successfully!'),
            backgroundColor: AppColors.success(context),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave program: $e'),
            backgroundColor: AppColors.error(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;

    return Scaffold(
   appBar: AppBar(
  toolbarHeight: 60, // Added from Members app bar
  title: const Text(
    'Program Details',
    style: TextStyle(
      color: Colors.white, // Changed to white
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  centerTitle: true, // Added from Members app bar
  backgroundColor: Colors.transparent, // Added for consistency
  foregroundColor: Colors.white, // Changed from iconTheme for consistency
  elevation: 0,

  systemOverlayStyle: SystemUiOverlayStyle( // Added from Members app bar
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background(context),
    systemNavigationBarIconBrightness: Brightness.dark,
  ),
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
      borderRadius: const BorderRadius.only( // Added rounded corners
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: 6,
          offset: const Offset(0, 2),
          color: Colors.black.withOpacity(0.3),
        ),
      ],
    ),
  ),
  leading: IconButton( // Added explicit back button
    icon: const Icon(
      Icons.arrow_back,
      color: Colors.white, // Changed to white
    ),
    onPressed: () => Navigator.pop(context),
  ),
  automaticallyImplyLeading: true, // Added for consistency
  // Add actions for join/leave functionality
  actions: currentUserId == null
      ? null // Don't show join/leave if user is not logged in
      : [
          StreamBuilder<List<ParticipantModel>>(
            stream: Provider.of<ParticipantProvider>(context, listen: false)
                .streamProgramParticipants(widget.programId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final participants = snapshot.data!;
              final hasUserJoined = participants.any(
                (p) => p.userId == currentUserId && p.status == 'joined',
              );

              return hasUserJoined
                  ? // Leave icon only
                  Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        onPressed: () => _leaveProgram(context),
                        icon: const Icon(
                          Icons.exit_to_app_rounded,
                          color: Colors.white, // Changed to white
                        ),
                        tooltip: 'Leave Program',
                      ),
                    )
                  : // Join Program button with background
                  Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _joinProgram(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15), // Semi-transparent white background
                          foregroundColor: Colors.white, // Changed to white
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.5),
                        ),
                        child: const Text( // Made const since color is fixed now
                          'Join',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white, // Changed to white
                          ),
                        ),
                      ),
                    );
            },
          ),
        ],
  bottom: TabBar(
    controller: _tabController,
      dividerColor: Colors.transparent, // 🔥 THIS FIXES IT
  dividerHeight: 0,   
    isScrollable: true,
    labelColor: Colors.white, // Changed to white
    unselectedLabelColor: Colors.white.withOpacity(0.7), // Changed to white with opacity
    indicatorColor: Colors.white, // Changed to white
    indicatorWeight: 3,
    indicatorPadding: const EdgeInsets.symmetric(horizontal: 0),
    labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    labelStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
    unselectedLabelStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
    tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
  ),
),
      body: StreamBuilder<ProgramModel?>(
        stream: programProvider.getProgramById(widget.programId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: AppColors.primary(context),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error(context),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Program not found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The program you are looking for does not exist',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            );
          }

          final program = snapshot.data!;

          return TabBarView(
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
          );
        },
      ),
    );
  }
}