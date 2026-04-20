// lib/features/dashboard/widgets/program_carousel_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'package:kofund/core/skeleton/program_card_skeleton.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:kofund/features/programs/models/program_model.dart';
import 'package:kofund/features/programs/screens/program_details_screen.dart';
import 'package:kofund/features/programs/screens/all_programs_screen.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/core/utils/haptic_helper.dart';

class ProgramCarouselWidget extends StatefulWidget {
  final bool isAdmin;

  const ProgramCarouselWidget({
    super.key,
    required this.isAdmin, // Changed from isAdmin = false to required
  });

  @override
  State<ProgramCarouselWidget> createState() => _ProgramCarouselWidgetState();
}

class _ProgramCarouselWidgetState extends State<ProgramCarouselWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.94);
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 DEBUG: ProgramCarouselWidget initState called');
    
    // Fast-cache check to bypass the loading skeleton flash for frame 0
    final authProvider = context.read<AppAuthProvider>();
    final programProvider = context.read<ProgramProvider>();
    final user = authProvider.user;
    
    if (user != null && user.communityId != null && 
        programProvider.programs.isNotEmpty && 
        programProvider.programs.first.communityId == user.communityId) {
      _isLoading = false;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadData();
    });
  }

  void _checkAuthAndLoadData() {
    if (!mounted) return;
    
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    final programProvider = context.read<ProgramProvider>();
    
    if (user == null) {
      debugPrint('❌ DEBUG: No user found in ProgramCarouselWidget');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Please sign in to view programs';
        });
      }
      
      programProvider.clearAllData();
      return;
    }
    
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
    
    debugPrint('✅ DEBUG: User found with community ${user.communityId}, loading programs...');
    _loadProgramsData(user.communityId!);
  }

  Future<void> _loadProgramsData(String communityId) async {
    if (!mounted) return;
    
    final programProvider = context.read<ProgramProvider>();
    final authProvider = context.read<AppAuthProvider>();
    
    // Determine if we have existing cached data for this community
    final hasExistingData = programProvider.programs.isNotEmpty && 
                            programProvider.programs.first.communityId == communityId;
    
    if (!hasExistingData) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    } else {
      // Immediately clear error states and rely on instant playback
      setState(() {
        _isLoading = false;
        _hasError = false;
        _errorMessage = null;
      });
    }
    
    try {
      // Fetch fresh data in the background
      await programProvider.loadCommunityPrograms(communityId);
      
      if (authProvider.user != null) {
        await programProvider.loadMyParticipations(
          authProvider.user!.uid,
          communityId,
        );
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('❌ DEBUG: Error loading programs data: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load programs';
        });
      }
    }
  }

  void _retryLoading() {
    _checkAuthAndLoadData();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final authProvider = context.watch<AppAuthProvider>();
    final user = authProvider.user;
    
    return _buildProgramsContent(user, isDarkMode);
  }

  void _navigateToAllPrograms(BuildContext context) {
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    if (user == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllProgramsScreen(
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  Widget _buildProgramsContent(UserModel? user, bool isDarkMode) {
    // If no user is logged in
    if (user == null) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: 'Sign in to View Programs',
        message: 'Please sign in to see community programs',
        isDarkMode: isDarkMode,
      );
    }
    
    // If user has no community
    if (user.communityId == null || user.communityId!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_outlined,
        title: 'No Community',
        message: 'Join a community to view programs',
        isDarkMode: isDarkMode,
      );
    }
    
    // If loading
    if (_isLoading) {
      return _buildLoadingState(isDarkMode);
    }
    
    // If error
    if (_hasError) {
      return _buildErrorState(isDarkMode);
    }
    
    // Show programs from provider
    return Consumer<ProgramProvider>(
    builder: (context, programProvider, child) {
      final activePrograms = programProvider.programs
          .where((program) => 
              program.isOngoing && 
              !program.isMonthlyPaymentProgram &&
              program.communityId == user.communityId)
          .toList();

      // If no active programs
      if (activePrograms.isEmpty) {
        return _buildEmptyState(
          icon: Icons.event_note,
          title: 'No Active Programs',
          message: 'Check back later for new programs',
          isDarkMode: isDarkMode,
        );
      }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header with icon and "See all" link
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 18,
                    color: AppColors.primary(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Active Programs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  if (activePrograms.length >= 2)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _navigateToAllPrograms(context),
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

            // Program carousel - CENTER THIS
// Program carousel with wider cards
// Program carousel with wider cards - UPDATE THE HEIGHT
SizedBox(
  height: 330,
  child: PageView.builder(
    controller: _pageController,
    itemCount: activePrograms.length,
    padEnds: true,
    physics: const BouncingScrollPhysics(),
    itemBuilder: (context, index) {
      final program = activePrograms[index];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _DashboardProgramCard(
          program: program,
          isAdmin: widget.isAdmin,
          isDarkMode: isDarkMode,
        ),
      );
    },
  ),
),

          ],
        ),
      );
    },
  );
}

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
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

  Widget _buildLoadingState(bool isDarkMode) {
    return Container(
  
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 120,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

       // Carousel skeleton with wider cards
SizedBox(
  height: 330,
  child: PageView.builder(
    controller: PageController(viewportFraction: 0.94), // Match the viewportFraction
    itemCount: 2,
    padEnds: true,
    physics: const NeverScrollableScrollPhysics(),
    itemBuilder: (context, index) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ProgramCardSkeleton(isDarkMode: isDarkMode),
      );
    },
  ),
),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
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
            _errorMessage ?? 'Failed to load programs',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error(context),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
}

// Reusable Dashboard Program Card
class _DashboardProgramCard extends StatefulWidget {
  final ProgramModel program;
  final bool isAdmin;
  final bool isDarkMode;

  const _DashboardProgramCard({
    required this.program,
    required this.isAdmin,
    required this.isDarkMode,
  });

  @override
  State<_DashboardProgramCard> createState() => __DashboardProgramCardState();
}

class __DashboardProgramCardState extends State<_DashboardProgramCard> {
  bool _isJoining = false;
  bool _isLeaving = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final user = authProvider.user;
    
    return Selector<ProgramProvider, bool>(
      selector: (_, p) => user != null ? p.hasUserJoined(widget.program.programId, user.uid) : false,
      builder: (context, hasJoined, _) {
        final programProvider = Provider.of<ProgramProvider>(context, listen: false);
        final canJoin = widget.program.canJoin && !hasJoined;
        
        return _buildCardWrapper(context, user, hasJoined, canJoin, programProvider, authProvider);
      },
    );
  }

  Widget _buildCardWrapper(BuildContext context, UserModel? user, bool hasJoined, bool canJoin, ProgramProvider programProvider, AppAuthProvider authProvider) {
    return RepaintBoundary(
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program header
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 12), // Reduced bottom padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Program type icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                      child: Icon(
                        ProgramTypes.getIconData(widget.program.programType),
                        size: 18,
                        color: AppColors.primary(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Title and participants
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.program.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.group_rounded,
                                size: 12,
                                color: AppColors.textSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              StreamBuilder<int>(
                                stream: programProvider.streamProgramParticipantCount(widget.program.programId),
                                builder: (context, snapshot) {
                                  final participantCount = snapshot.data ?? widget.program.currentParticipants;
                                  final maxParticipants = widget.program.maxParticipants;
                                  final isFull = widget.program.isFixedParticipants && participantCount >= maxParticipants;
                                  
                                  return Text(
                                    "$participantCount/${widget.program.isFixedParticipants ? maxParticipants : '∞'} participants",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isFull 
                                          ? AppColors.error(context)
                                          : AppColors.textSecondary(context),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Joined badge
                    if (hasJoined)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'Joined',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Date and location
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                  if (!widget.program.isMonthlyPaymentProgram && widget.program.programDate != null)
  Text(
    _formatDate(widget.program.programDate!),
    style: TextStyle(
      fontSize: 11,
      color: AppColors.textSecondary(context),
    ),
  ),
                    if (widget.program.location.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.program.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border(context).withValues(alpha: 0.3),
          ),
          
          // Financial stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: programProvider.streamProgramFinancialSummary(widget.program.programId),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {
                  'collected': 0.0,
                  'expenses': 0.0,
                  'balance': 0.0,
                };
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildStatItemCompact(
                        'Collected',
                        Icons.account_balance_wallet_rounded,
                        AppColors.primary(context),
                        stats['collected'] ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatItemCompact(
                        'Expenses',
                        Icons.money_off_rounded,
                        AppColors.primary(context),
                        stats['expenses'] ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatItemCompact(
                        'Balance',
                        Icons.savings_rounded,
                        AppColors.primary(context),
                        stats['balance'] ?? 0.0,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border(context).withValues(alpha: 0.3),
          ),
          
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: programProvider.streamProgramProgress(widget.program.programId),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {
                  'collected': 0.0,
                  'target': 100.0,
                  'percentage': 0.0,
                };
                
                final collected = (data['collected'] as num).toDouble();
                final target = (data['target'] as num).toDouble();
                final progress = (data['percentage'] as num).toDouble();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.progressBackground(context),
                        color: AppColors.progressFill(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${collected.toStringAsFixed(0)} of ₹${target.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Action buttons - ADD THIS TO FILL REMAINING SPACE
          const Spacer(),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Added bottom padding
            child: Row(
              children: [
                // View Details button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewProgramDetails(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(context),
                      side: BorderSide(
                        color: AppColors.border(context),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Join/Leave button
                if (hasJoined)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(
                        color:Colors.red.withValues(alpha: 0.3) ,
                      ),
                    ),
                    child: IconButton(
                      icon: _isLeaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            )
                          : const Icon(
                              Icons.exit_to_app_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                      onPressed: _isLeaving ? null : () => _leaveProgram(programProvider, authProvider),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canJoin ? () => _joinProgram(programProvider, authProvider) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canJoin
                            ? AppColors.primary(context)
                            : AppColors.textTertiary(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: _isJoining
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              !canJoin && widget.program.isFixedParticipants && 
                              widget.program.currentParticipants >= widget.program.maxParticipants
                                  ? 'Program Full'
                                  : 'Join Now',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildStatItemCompact(
    String label,
    IconData icon,
    Color color,
    double value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${value.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinProgram(ProgramProvider programProvider, AppAuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isJoining = true);

    try {
      await programProvider.joinProgram(
        widget.program,
        user.uid,
        user.displayName ?? user.email,
        user.email,
        widget.program.communityId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${widget.program.title} successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  Future<void> _leaveProgram(ProgramProvider programProvider, AppAuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;

    final confirm = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Leave Program?',
      message: 'Are you sure you want to leave ${widget.program.title}?',
      confirmLabel: 'Leave',
      icon: Icons.exit_to_app_rounded,
      isDestructive: true,
    );

    if (confirm == true) {
      HapticHelper.success();
      setState(() => _isLeaving = true);

      try {
        await programProvider.leaveProgram(widget.program.programId, user.uid);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left ${widget.program.title}'),
            backgroundColor: Colors.green,
          ),
        );
        
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLeaving = false);
      }
    }
  }

  void _viewProgramDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramDetailsScreen(programId: widget.program.programId),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return 'In ${difference.inDays} days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}


