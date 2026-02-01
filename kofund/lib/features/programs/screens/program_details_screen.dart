import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import
import 'package:shimmer/shimmer.dart';

import '../models/program_model.dart';
import '../providers/program_provider.dart';
import '../../../features/participants/providers/participant_provider.dart';
import '../../../features/participants/models/participant_model.dart';
import '../../../features/auth/providers/app_auth_provider.dart';
import 'tabs/program_overview_tab.dart';
import 'tabs/program_participants_tab.dart';
import 'tabs/program_contributions_tab.dart';
import 'tabs/program_expenses_tab.dart';
import '../../../../core/constants/app_colors.dart';

// Import skeleton files
import '../../../../core/skeleton/program_overview_skeleton.dart';
import '../../../../core/skeleton/program_participants_skeleton.dart';
import '../../../../core/skeleton/program_contributions_skeleton.dart';
import '../../../../core/skeleton/program_expenses_skeleton.dart';

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
    'Expenses'
  ];

  bool _isProgramLoading = true;
  ProgramModel? _cachedProgram;
  final RefreshController _refreshController = RefreshController(); // Add this

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _loadProgramData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose(); // Dispose refresh controller
    super.dispose();
  }

  Future<void> _loadProgramData() async {
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    
    try {
      programProvider.getProgramById(widget.programId).listen((program) {
        if (program != null) {
          setState(() {
            _cachedProgram = program;
            _isProgramLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isProgramLoading = false;
      });
    }
  }

// Replace your _refreshAllData method with this:
Future<void> _refreshAllData() async {
  debugPrint('🔄 DEBUG: Refreshing all program details data...');
  
  try {
    // Show loading state
    if (mounted) {
      setState(() {
        _isProgramLoading = true;
      });
    }
    
    // Get providers
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    
    // Clear the cached program to force re-fetch
    setState(() {
      _cachedProgram = null;
    });
    
    // Method 1: Use refreshProgramData if you added it to ProgramProvider
    try {
      await programProvider.refreshProgramData(widget.programId);
    } catch (e) {
      debugPrint('⚠️ Could not call refreshProgramData: $e');
    }
    
    // Method 2: Force re-fetch the program from Firestore
    // This is the most reliable way
    await programProvider.loadCommunityPrograms(_cachedProgram?.communityId ?? '');
    
    // Wait a bit for Firestore to update
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Get fresh program data
    final freshProgram = await programProvider.getProgramById(widget.programId).first;
    
    if (mounted) {
      setState(() {
        _cachedProgram = freshProgram;
        _isProgramLoading = false;
      });
    }
    
    // Complete the refresh
    _refreshController.refreshCompleted();
    debugPrint('✅ DEBUG: All program details refreshed successfully');
    
  } catch (e) {
    debugPrint('❌ DEBUG: Error refreshing program details: $e');
    
    if (mounted) {
      setState(() {
        _isProgramLoading = false;
      });
    }
    
    _refreshController.refreshFailed();
    
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to refresh: ${e.toString()}'),
        backgroundColor: AppColors.error(context),
      ),
    );
  }
}

  void _onRefresh() {
    _refreshAllData();
  }

  // ... rest of your existing methods (joinProgram, leaveProgram, buildTabSkeleton)

  Widget _buildTabSkeleton(int tabIndex) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final isMonthlyProgram = _cachedProgram?.isMonthlyPaymentProgram ?? false;
    
    switch (tabIndex) {
      case 0:
        return ProgramOverviewSkeleton(isDarkMode: isDarkMode);
      case 1:
        return ProgramParticipantsSkeleton(
          isDarkMode: isDarkMode,
          isMonthlyProgram: isMonthlyProgram,
        );
      case 2:
        return ProgramContributionsSkeleton(isDarkMode: isDarkMode);
      case 3:
        return ProgramExpensesSkeleton(isDarkMode: isDarkMode);
      default:
        return ProgramOverviewSkeleton(isDarkMode: isDarkMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        title: const Text(
          'Program Details',
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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.background(context),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                offset: const Offset(0, 2),
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        automaticallyImplyLeading: true,
        actions: currentUserId == null || _isProgramLoading
            ? null
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
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              onPressed: () => _leaveProgram(context),
                              icon: const Icon(
                                Icons.exit_to_app_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'Leave Program',
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ElevatedButton(
                              onPressed: () => _joinProgram(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                                shadowColor: Colors.black.withValues(alpha: 0.5),
                              ),
                              child: const Text(
                                'Join',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                  },
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          dividerColor: Colors.transparent,
          dividerHeight: 0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorPadding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
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
          tabs: _tabTitles
              .map(
                (title) => Tab(
                  child: Center(
                    child: Text(title),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: _isProgramLoading
          ? _buildTabSkeleton(_tabController.index)
          : _cachedProgram != null
              ? SmartRefresher( // Wrap with SmartRefresher
                  controller: _refreshController,
                  onRefresh: _onRefresh,
                  enablePullDown: true,
                  enablePullUp: false,
                  physics: const BouncingScrollPhysics(),
                  header: ClassicHeader(
                    idleText: 'Pull down to refresh',
                    releaseText: 'Release to refresh',
                    refreshingText: 'Refreshing program data...',
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
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ProgramOverviewTab(program: _cachedProgram!),
                      ProgramParticipantsTab(program: _cachedProgram!),
                      ProgramContributionsTab(program: _cachedProgram!),
                      ProgramExpensesTab(program: _cachedProgram!),
                    ],
                  ),
                )
              : SmartRefresher( // Also wrap error state with SmartRefresher
                  controller: _refreshController,
                  onRefresh: _onRefresh,
                  enablePullDown: true,
                  enablePullUp: false,
                  child: Center(
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _onRefresh,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // Join program method (keep existing)
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

      final program = await programProvider.getProgramById(widget.programId).first;
      if (program == null) return;

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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined the program!'),
          backgroundColor: AppColors.success(context),
        ),
      );
      
      // Refresh data after joining
      _refreshAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join program: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

  // Leave program method (keep existing)
  Future<void> _leaveProgram(BuildContext context) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final participantProvider =
        Provider.of<ParticipantProvider>(context, listen: false);

    final currentUser = authProvider.user;
    if (currentUser == null) return;

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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
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
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left the program successfully!'),
            backgroundColor: AppColors.success(context),
          ),
        );
        
        // Refresh data after leaving
        _refreshAllData();
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
}

