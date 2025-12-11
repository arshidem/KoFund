import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/programs/models/program_model.dart';
import 'package:kofund/features/programs/screens/program_details_screen.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/core/skeleton/program_card_skeleton.dart';

// ✅ IMPORT PROGRAM TYPES
import 'package:kofund/features/programs/constants/program_types.dart';

class ProgramCarouselWidget extends StatefulWidget {
  final String communityId;
  final bool isAdmin;

  const ProgramCarouselWidget({
    super.key,
    required this.communityId,
    this.isAdmin = false,
  });

  @override
  State<ProgramCarouselWidget> createState() => _ProgramCarouselWidgetState();
}

class _ProgramCarouselWidgetState extends State<ProgramCarouselWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final programProvider = context.read<ProgramProvider>();
      final authProvider = context.read<AppAuthProvider>();
      
      // ✅ EXACT SAME LOGIC AS ALL PROGRAMS SCREEN
      await programProvider.loadCommunityPrograms(widget.communityId);
      
      if (authProvider.user != null) {
        await programProvider.loadMyParticipations(
          authProvider.user!.uid,
          widget.communityId,
        );
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading programs for carousel: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Active Programs",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to All Programs screen
                  // You'll need to implement this navigation
                },
                style: TextButton.styleFrom(
                  foregroundColor:
                      isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
                child: const Text("View All"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Carousel Content
        _buildCarouselContent(isDarkMode),
      ],
    );
  }

  Widget _buildCarouselContent(bool isDarkMode) {
    if (_isLoading) {
      return _buildLoadingSkeleton(isDarkMode);
    }

    return Consumer<ProgramProvider>(
      builder: (context, programProvider, child) {
        // ✅ EXACT SAME FILTER LOGIC AS ALL PROGRAMS SCREEN
        final activePrograms = programProvider.programs
            .where((program) => 
                program.isOngoing && 
                !program.isMonthlyPaymentProgram &&
                program.communityId == widget.communityId)
            .toList();

        if (activePrograms.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        return SizedBox(
          height: 320, // Same height as your dashboard cards
          child: PageView.builder(
            controller: _pageController,
            itemCount: activePrograms.length,
            itemBuilder: (context, index) {
              final program = activePrograms[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: _DashboardProgramCard(
                  program: program,
                  isDarkMode: isDarkMode,
                  isAdmin: widget.isAdmin,
                ),
              );
            },
          ),
        
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(bool isDarkMode) {
    return SizedBox(
      height: 320,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: ProgramCardSkeleton(isDarkMode: isDarkMode),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note,
              size: 48,
              color: isDarkMode
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
          const SizedBox(height: 12),
          Text("No Active Programs",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              )),
          const SizedBox(height: 8),
          Text("Check back later for new programs",
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              )),
        ],
      ),
    );
  }
}

// 🎯 REUSABLE DASHBOARD PROGRAM CARD (Same logic as All Programs Screen)
class _DashboardProgramCard extends StatefulWidget {
  final ProgramModel program;
  final bool isDarkMode;
  final bool isAdmin;

  const _DashboardProgramCard({
    required this.program,
    required this.isDarkMode,
    required this.isAdmin,
  });

  @override
  State<_DashboardProgramCard> createState() => __DashboardProgramCardState();
}

class __DashboardProgramCardState extends State<_DashboardProgramCard> {
  bool _isJoining = false;
  bool _isLeaving = false;

  @override
  Widget build(BuildContext context) {
    final programProvider = context.watch<ProgramProvider>();
    final authProvider = context.watch<AppAuthProvider>();
    final user = authProvider.user;
    
    // ✅ EXACT SAME LOGIC AS ALL PROGRAMS SCREEN
    final hasJoined = user != null 
        ? programProvider.hasUserJoined(widget.program.programId, user.uid)
        : false;
    
    final canJoin = widget.program.canJoin && !hasJoined;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER - Title + Real-time Participants + Joined Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    // ✅ ONLY CHANGE: Use ProgramTypes.getIconData
                    CircleAvatar(
                      backgroundColor: (widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary).withOpacity(0.12),
                      radius: 16,
                      child: Icon(
                        ProgramTypes.getIconData(widget.program.programType), // ✅ Updated
                        color: widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.program.title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
           
              
              // Real-time Participant Count
              StreamBuilder<int>(
                stream: programProvider.streamProgramParticipantCount(widget.program.programId),
                builder: (context, snapshot) {
                  final participantCount = snapshot.data ?? widget.program.currentParticipants;
                  final maxParticipants = widget.program.maxParticipants;
                  final isFull = widget.program.isFixedParticipants && participantCount >= maxParticipants;
                  
                  return Row(
                    children: [
                      Icon(
                        Icons.group,
                        size: 16,
                        color: widget.isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$participantCount/${widget.program.isFixedParticipants ? maxParticipants : '∞'}",
                        style: TextStyle(
                          color: isFull 
                            ? (widget.isDarkMode ? AppColors.darkError : AppColors.lightError)
                            : (widget.isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 6),

          // DATE
          Text(
            _formatDate(widget.program.programDate),
            style: TextStyle(
              color: widget.isDarkMode
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 20),

          // REAL-TIME: Financial data with streams
          _buildFinancialSection(programProvider),

          const SizedBox(height: 18),

          // REAL-TIME: Progress with stream
          _buildProgressSection(programProvider),

          const SizedBox(height: 20),

          // ✅ ACTION BUTTONS - EXACT SAME LOGIC AS ALL PROGRAMS SCREEN
          _buildActionButtons(hasJoined, canJoin, programProvider, authProvider),
        ],
      ),
    );
  }

  // ✅ EXACT SAME BUTTON LOGIC AS ALL PROGRAMS SCREEN
Widget _buildActionButtons(bool hasJoined, bool canJoin, ProgramProvider programProvider, AppAuthProvider authProvider) {
  final user = authProvider.user;
  
  return Row(
    children: [
      // View Details Button
      Expanded(
        child: ElevatedButton(
          onPressed: () => _viewProgramDetails(widget.program),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
            foregroundColor: widget.isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            side: BorderSide(
              color: widget.isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text("View Details"),
        ),
      ),

      const SizedBox(width: 8),

      // Join/Leave Button
      if (hasJoined) ...[
        IconButton(
          icon: _isLeaving
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                )
              : const Icon(Icons.exit_to_app, color: Colors.red),
          onPressed: _isLeaving ? null : () => _leaveProgram(programProvider, authProvider),
        ),
      ] else ...[
        Expanded(
          child: ElevatedButton(
            onPressed: canJoin ? () => _joinProgram(programProvider, authProvider) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canJoin
                  ? (widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary)
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isJoining
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    !canJoin && widget.program.isFixedParticipants && widget.program.currentParticipants >= widget.program.maxParticipants
                        ? 'Program Full'
                        : 'Join Now',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    ],
  );
}

  // Financial Section
  Widget _buildFinancialSection(ProgramProvider programProvider) {
    return StreamBuilder<double>(
      stream: programProvider.streamProgramTotalContributions(widget.program.programId),
      builder: (context, contribSnap) {
        final collected = contribSnap.data ?? 0.0;

        return FutureBuilder<double>(
          future: _getProgramExpenses(widget.program.programId),
          builder: (context, expenseSnap) {
            final expenses = expenseSnap.data ?? 0.0;
            final balance = collected - expenses;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ✅ ONLY CHANGE: Use consistent icon colors
                _buildStatWithIcon(
                  Icons.account_balance_wallet,
                  "Collected",
                  "₹${collected.toStringAsFixed(2)}",
                  widget.isDarkMode ? AppColors.darkRevenue : AppColors.lightRevenue,
                ),
                _buildStatWithIcon(
                  Icons.money_off,
                  "Expenses",
                  "₹${expenses.toStringAsFixed(2)}",
                  widget.isDarkMode ? AppColors.darkExpense : AppColors.lightExpense,
                ),
                _buildStatWithIcon(
                  Icons.savings,
                  "Balance",
                  "₹${balance.toStringAsFixed(2)}",
                  widget.isDarkMode ? AppColors.darkBalance : AppColors.lightBalance,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Progress Section
  Widget _buildProgressSection(ProgramProvider programProvider) {
    final target = widget.program.totalProgramAmount ?? 0.0;

    return StreamBuilder<double>(
      stream: programProvider.streamProgramTotalContributions(widget.program.programId),
      builder: (context, contribSnap) {
        final collected = contribSnap.data ?? 0.0;
        final rawProgress = target > 0 ? (collected / target) : 0.0;
        final progress = (rawProgress.clamp(0.0, 1.0) as double);

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: widget.isDarkMode
                    ? AppColors.darkProgressBackground
                    : AppColors.lightProgressBackground,
                color: widget.isDarkMode ? AppColors.darkProgressFill : AppColors.lightProgressFill,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "₹${collected.toStringAsFixed(2)} / ₹${target.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  "${(progress * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ✅ JOIN PROGRAM - EXACT SAME AS ALL PROGRAMS SCREEN
  Future<void> _joinProgram(ProgramProvider programProvider, AppAuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isJoining = true);

    try {
      await programProvider.joinProgram(
        widget.program,
        user.uid,
        user.displayName ?? user.email ?? 'Member',
        user.email ?? '',
        widget.program.communityId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${widget.program.title} successfully')),
      );
      
      // ✅ Force UI update
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: $e')),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  // ✅ LEAVE PROGRAM - EXACT SAME AS ALL PROGRAMS SCREEN
  Future<void> _leaveProgram(ProgramProvider programProvider, AppAuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Program?'),
        content: Text('Are you sure you want to leave ${widget.program.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Leave', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLeaving = true);

      try {
        await programProvider.leaveProgram(widget.program.programId, user.uid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Left ${widget.program.title}')),
        );
        
        // ✅ Force UI update
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave: $e')),
        );
      } finally {
        setState(() => _isLeaving = false);
      }
    }
  }

  // Helper Methods
  Future<double> _getProgramExpenses(String programId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('programId', isEqualTo: programId)
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'pending';
        if (status == 'approved' || status == 'completed') {
          total += (data['amount'] ?? 0).toDouble();
        }
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  void _viewProgramDetails(ProgramModel program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramDetailsScreen(programId: program.programId),
      ),
    );
  }

  Widget _buildStatWithIcon(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: widget.isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        )
      ],
    );
  }
}