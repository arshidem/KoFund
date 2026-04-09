import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/dialog_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import '../providers/program_provider.dart';
import '../models/program_model.dart';
import '../constants/program_types.dart';
import 'create_program_screen.dart';
import 'program_details_screen.dart';
import 'edit_program_screen.dart';
import 'program_reminder_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:kofund/core/skeleton/all_program_skeleton.dart';
import '../../participants/models/participant_model.dart';
import '../../participants/providers/participant_provider.dart';
enum ProgramStatusFilter {
  all,
  ongoing,
  completed,
  cancelled,
}

class ProgramFilters {
  ProgramStatusFilter statusFilter;
  String? programType;
  bool? monthlyOnly;
  bool? availableOnly;

  ProgramFilters({
    this.statusFilter = ProgramStatusFilter.all,
    this.programType,
    this.monthlyOnly,
    this.availableOnly,
  });

  ProgramFilters copyWith({
    ProgramStatusFilter? statusFilter,
    String? programType,
    bool? monthlyOnly,
    bool? availableOnly,
    bool clearProgramType = false,
  }) {
    return ProgramFilters(
      statusFilter: statusFilter ?? this.statusFilter,
      programType: clearProgramType ? null : (programType ?? this.programType),
      monthlyOnly: monthlyOnly ?? this.monthlyOnly,
      availableOnly: availableOnly ?? this.availableOnly,
    );
  }
}

class AllProgramsScreen extends StatefulWidget {
  final bool isAdmin;

  const AllProgramsScreen({
    super.key,
    required this.isAdmin,
  });

  @override
  State<AllProgramsScreen> createState() => _AllProgramsScreenState();
}

class _AllProgramsScreenState extends State<AllProgramsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController();
  String _searchQuery = '';
  ProgramFilters _filters = ProgramFilters();

  int _getActiveFilterCount() {
    int count = 0;
    if (_filters.statusFilter != ProgramStatusFilter.all) count++;
    if (_filters.programType != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadPrograms();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _navigateToRemindersScreen(ProgramModel program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramRemindersScreen(program: program),
      ),
    );
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Reactive Loading: If auth data arrives late, trigger load
    final authProvider = Provider.of<AppAuthProvider>(context);
    final programProvider = Provider.of<ProgramProvider>(context, listen: false);
    
    if (authProvider.user?.communityId != null && 
        programProvider.programs.isEmpty && 
        !programProvider.isLoading) {
      _loadPrograms();
    }
  }

  Future<void> _loadPrograms() async {
    // Ensure we don't call this if the widget is not mounted or in a precarious state
    if (!mounted) return;
    
    final authProvider = context.read<AppAuthProvider>();
    final programProvider = context.read<ProgramProvider>();
    
    final communityId = authProvider.user?.communityId;
    if (communityId != null) {
      debugPrint('📥 Loading programs for community: $communityId');
      await programProvider.loadCommunityPrograms(communityId);
      
      if (mounted) {
        await programProvider.loadMyParticipations(
          authProvider.user!.uid, 
          communityId,
        );
        
        // Use postFrame to avoid modifying state during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) programProvider.syncAllProgramsStatus();
        });
      }
    } else {
      debugPrint('⚠️ Cannot load programs: communityId is null');
    }
  }

  Future<void> _onRefresh() async {
    HapticHelper.light();
    debugPrint('🔄 DEBUG: Pull to refresh triggered in Programs');
    
    try {
      await _loadPrograms();
      debugPrint('✅ DEBUG: Programs refresh completed successfully');
    } catch (e) {
      debugPrint('❌ DEBUG: Programs refresh failed: $e');
    }
  }

List<ProgramModel> _applyFilters(List<ProgramModel> programs) {
  return programs.where((program) {
    if (_filters.statusFilter != ProgramStatusFilter.all) {
      switch (_filters.statusFilter) {
        case ProgramStatusFilter.ongoing:
          if (!program.isOngoing) return false; // This now uses computedStatus
          break;
        case ProgramStatusFilter.completed:
          if (!program.isCompleted) return false; // This now uses computedStatus
          break;
        case ProgramStatusFilter.cancelled:
          if (!program.isCancelled) return false; // This now uses computedStatus
          break;
        default:
          break;
      }
    }

      if (_filters.programType != null && _filters.programType != 'all') {
        if (program.programType != _filters.programType) return false;
      }

      if (_filters.monthlyOnly == true) {
        if (!program.isMonthlyPaymentProgram) return false;
      }

      if (_filters.availableOnly == true) {
        if (!program.canJoin) return false;
      }

      return true;
    }).toList();
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusExtraLarge)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.65,
          child: FilterSheet(
            filters: _filters,
            onFiltersChanged: (newFilters) {
              setState(() {
                _filters = newFilters;
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final programProvider = context.watch<ProgramProvider>();
    final isAdmin = widget.isAdmin;
    List<ProgramModel> filteredPrograms = programProvider.programs;
    
    if (_searchQuery.isNotEmpty) {
      filteredPrograms = filteredPrograms.where((program) {
        return program.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               program.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               program.location.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // ✅ APPLY SELECTED FILTERS
    filteredPrograms = _applyFilters(filteredPrograms);
    
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context),
          ];
        },
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async => _onRefresh(),
            ),
            _buildActiveFilterChips(),
            _buildBodyContent(programProvider, filteredPrograms),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _navigateToCreateProgram(context),
              backgroundColor: const Color(0xFF00BFA5),
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    const double toolbarHeight = 64.0;
    const double totalBottomHeight = 64.0 + 24.0;

    // Dynamic collapsed/expanded calculation
    final double collapsedHeight = toolbarHeight + totalBottomHeight;
    final double expandedHeight = collapsedHeight + 36.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      toolbarHeight: toolbarHeight,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent, // Let flexibleSpace handle color
      automaticallyImplyLeading: false,
      // Dynamic Title using flexibleSpace for scaling effect
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          final double currentHeight = top;
          
          // Normalized progress: 0.0 at collapsed, 1.0 at expanded
          final double progress = ((currentHeight - collapsedHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
          
          // Font size: 20 at expanded, 18 at collapsed
          final double fontSize = 18 + (2 * progress); // 18 to 20 scaling
          // Vertical offset for title - center it vertically above the search bar
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // 🔋 PERSISTENT GRADIENT BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient(context),
                ),
              ),
              
              FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                centerTitle: true,
                titlePadding: const EdgeInsets.only(
                  bottom: totalBottomHeight + 10,
                ),
                title: Text(
                  'Programs',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5 - (0.5 * progress),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(totalBottomHeight),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(AppDimensions.screenPaddingHorizontal, 0, AppDimensions.screenPaddingHorizontal, 12),
              child: _buildModernSearchBar(),
            ),
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.radiusExtraLarge),
                  topRight: Radius.circular(AppDimensions.radiusExtraLarge),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Widget _buildModernSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Search programs...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              onTap: () => _openFilterSheet(context),
              child: Center(
                child: badges.Badge(
                  showBadge: _getActiveFilterCount() > 0,
                  badgeContent: Text(
                    _getActiveFilterCount().toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.error(context),
                    padding: const EdgeInsets.all(4),
                    elevation: 0,
                  ),
                  position: badges.BadgePosition.topEnd(top: -6, end: -6),
                  child: const Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(int resultCount) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary(context).withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: AppColors.primary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search results for "$_searchQuery"',
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
            ),
            child: Text(
              '$resultCount ${resultCount == 1 ? 'program' : 'programs'}',
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildBodyContent(ProgramProvider programProvider, List<ProgramModel> displayedPrograms) {
  final bgColor = AppColors.background(context);
  
  if (programProvider.isLoading && displayedPrograms.isEmpty) {
    return ProgramListSkeleton.buildSliver(
      context, 
      Theme.of(context).brightness == Brightness.dark,
    );
  }

  if (programProvider.error != null && displayedPrograms.isEmpty) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                programProvider.error!,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPrograms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  if (displayedPrograms.isEmpty) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Container(
        color: bgColor,
        child: _buildEmptyState(),
      ),
    );
  }

  return SliverPadding(
    padding: const EdgeInsets.only(top: 16),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final program = displayedPrograms[index];
          return Container(
            color: bgColor,
            child: TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: _buildProgramCard(program, programProvider, context.read<AppAuthProvider>()),
            ),
          );
        },
        childCount: displayedPrograms.length,
      ),
    ),
  );
}

  Widget _buildEmptyState() {
    final isAdmin = widget.isAdmin;

    return Padding(
      padding: const EdgeInsets.only(top: 80, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEmptyIcon(),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'No results found' : 'No Programs Available',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchQuery.isNotEmpty 
                  ? 'Try adjusting your search or filters'
                  : isAdmin
                      ? 'Create the first program for your community.'
                      : 'No programs available yet. Check back later.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          if (_searchQuery.isNotEmpty)
            _buildActionButton('Clear Search', () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            })
          else
            _buildActionButton('Refresh Programs', _loadPrograms, icon: Icons.refresh_rounded),
        ],
      ),
    );
  }

  Widget _buildEmptyIcon() {
    final color = AppColors.primary(context).withValues(alpha: 0.5);
    if (_searchQuery.isNotEmpty) {
      return Icon(Icons.search_off, size: 64, color: color);
    }
    return Icon(Icons.event_note_rounded, size: 64, color: color);
  }

  Widget _buildActionButton(String label, VoidCallback onPressed, {IconData? icon}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary(context),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
      ),
    );
  }


// Premium Program Card Section

// Replace the _buildProgramCard method with this corrected version

Widget _buildProgramCard(
  ProgramModel program,
  ProgramProvider programProvider,
  AppAuthProvider authProvider,
) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final hasJoined = programProvider.hasUserJoined(program.programId, authProvider.user!.uid);
  final programColor = _getProgramColor(program.programType);

  return Consumer<ParticipantProvider>(
    builder: (context, participantProvider, _) {
      return Container(
        margin: EdgeInsets.fromLTRB(AppDimensions.screenPaddingHorizontal, 0, AppDimensions.screenPaddingHorizontal, 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: InkWell(
          onTap: () => _viewProgramDetails(program),
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          child: StreamBuilder<double>(
                  stream: programProvider.streamProgramTotalContributions(program.programId),
                  builder: (context, contribSnap) {
                    final collectedAmount = contribSnap.data ?? 0.0;
                    return StreamBuilder<List<ParticipantModel>>(
                      stream: participantProvider.streamProgramParticipants(program.programId),
                      builder: (context, participantSnapshot) {
                        final participants = participantSnapshot.data ?? [];
                        final totalParticipants = participants.length;
                        final maxParticipants = program.maxParticipants ?? 0;
                        
                        double programAmount = 0.0;
                        if (program.totalProgramAmount != null && program.totalProgramAmount! > 0) {
                          programAmount = program.totalProgramAmount!;
                        } else if (program.suggestedContribution != null && program.suggestedContribution! > 0) {
                          final pCount = program.isFixedParticipants ? maxParticipants : totalParticipants;
                          programAmount = program.suggestedContribution! * (pCount > 0 ? pCount : 1);
                        }

                        final progress = programAmount > 0 ? (collectedAmount / programAmount).clamp(0.0, 1.0) : 0.0;
                        final now = DateTime.now();
                        final daysLeft = (program.isMonthlyPaymentProgram || program.programDate == null)
                            ? null 
                            : program.programDate!.difference(now).inDays;
                        final isEnding = daysLeft != null && daysLeft <= 3 && daysLeft >= 0;
                        final hasEnded = daysLeft != null && daysLeft < 0;

                        final canJoin = !hasJoined &&
                            (!program.isFixedParticipants ||
                                (program.maxParticipants > totalParticipants));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Icon + Title + Status/Admin
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: programColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                                  ),
                                  child: Icon(
                                    ProgramTypes.getIconData(program.programType),
                                    color: programColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        program.title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary(context),
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        program.programType.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: programColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.isAdmin)
                                  _buildAdminMenu(program, programProvider)
                                else
                                  _buildStatusBadge(program, progress, daysLeft ?? 0),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (program.description.isNotEmpty) ...[
                              Text(
                                program.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary(context),
                                  height: 1.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                            ],
                            Column(
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
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: programColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Stack(
                                      children: [
                                        Container(
                                          height: 8,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: programColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        TweenAnimationBuilder<double>(
                                          duration: const Duration(milliseconds: 1200),
                                          curve: Curves.easeOutQuart,
                                          tween: Tween<double>(begin: 0, end: progress),
                                          builder: (context, animValue, child) {
                                            return Container(
                                              height: 8,
                                              width: constraints.maxWidth * animValue,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [programColor, programColor.withValues(alpha: 0.7)],
                                                ),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildCompactStat(
                                      Icons.people_outline_rounded,
                                      '$totalParticipants${maxParticipants > 0 ? "/$maxParticipants" : ""}',
                                    ),
                                    const SizedBox(width: 16),
                                    _buildCompactStat(
                                      Icons.account_balance_wallet_outlined,
                                      '₹${collectedAmount.toInt()}',
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: hasJoined 
                                    ? () => _viewProgramDetails(program)
                                    : (canJoin ? () => _joinProgram(program, programProvider, authProvider) : null),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: hasJoined || canJoin ? programColor : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      boxShadow: [
                                        if (hasJoined || canJoin)
                                          BoxShadow(
                                            color: programColor.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          hasJoined ? 'DETAILS' : (canJoin ? 'JOIN NOW' : 'Full'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: hasJoined || canJoin ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded, 
                                          size: 10, 
                                          color: hasJoined || canJoin ? Colors.white : Colors.white.withValues(alpha: 0.6)
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
              ),  // StreamBuilder<double>
          ),  // InkWell child
        );  // Container return
      },  // Consumer builder
    );  // Consumer
  }  // _buildProgramCard
// Your existing _buildStatItem method (unchanged)
// Replaced by compact stat helpers




  Widget _buildAdminMenu(ProgramModel program, ProgramProvider programProvider) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: AppColors.textTertiary(context),
        size: 22,
      ),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      color: AppColors.card(context),
      onSelected: (value) {
        if (value == 'edit') {
          _editProgram(program);
        } else if (value == 'delete') {
          _showDeleteConfirmation(program, programProvider);
        } else if (value == 'reminders') {
          _navigateToRemindersScreen(program);
        }
      },
      itemBuilder: (BuildContext context) => [
        _buildPopupMenuItem(
          value: 'edit',
          icon: Icons.edit_rounded,
          label: 'Edit Program',
          color: AppColors.primary(context),
        ),
        _buildPopupMenuItem(
          value: 'reminders',
          icon: Icons.notifications_active_rounded,
          label: 'Reminders',
          color: Colors.orange,
        ),
        _buildPopupMenuItem(
          value: 'delete',
          icon: Icons.delete_outline_rounded,
          label: 'Delete Program',
          color: AppColors.error(context),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  void _editProgram(ProgramModel program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProgramScreen(
          program: program,
          onProgramUpdated: () {
            _loadPrograms();
            SnackbarHelper.showSuccess(context, 'Program updated successfully!');
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ProgramModel program, ProgramProvider programProvider) async {
    final result = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Delete Program?',
      message: 'Are you sure you want to delete "${program.title}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (result == true) {
      _deleteProgram(program, programProvider);
    }
  }

  Future<void> _deleteProgram(ProgramModel program, ProgramProvider programProvider) async {
    try {
      await programProvider.deleteProgram(program.programId);
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, 'Program deleted successfully');
      _loadPrograms();
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to delete program: $e');
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _navigateToCreateProgram(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateProgramScreen()),
    ).then((_) => _loadPrograms());
  }

  void _viewProgramDetails(ProgramModel program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramDetailsScreen(programId: program.programId),
      ),
    );
  }

  Future<void> _joinProgram(
      ProgramModel program,
      ProgramProvider programProvider,
      AppAuthProvider authProvider) async {
    try {
      await programProvider.joinProgram(
        program,
        authProvider.user!.uid,
        authProvider.user!.displayName ?? 'Member',
        authProvider.user!.email ?? '',
        authProvider.user!.communityId!,
      );
      SnackbarHelper.showSuccess(context, 'Joined ${program.title}');
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to join: $e');
    }
  }

  Future<void> _leaveProgram(
      ProgramModel program,
      ProgramProvider programProvider,
      AppAuthProvider authProvider) async {
    final confirm = await DialogHelper.showConfirmationDialog(
      context,
      title: 'Leave Program?',
      message: 'Are you sure you want to leave ${program.title}?',
      confirmLabel: 'Yes, Leave',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await programProvider.leaveProgram(program.programId, authProvider.user!.uid);
        if (!mounted) return;
        SnackbarHelper.showInfo(context, 'Left ${program.title}');
      } catch (e) {
        SnackbarHelper.showError(context, 'Failed to leave: $e');
      }
    }
  }

  Widget _buildStatusBadge(ProgramModel program, double progress, int daysLeft) {
    String statusText;
    Color statusColor;
    
    if (program.isCompleted) {
      statusText = 'Completed';
      statusColor = Colors.green;
    } else if (daysLeft < 0) {
      statusText = 'Expired';
      statusColor = Colors.grey;
    } else if (daysLeft <= 3) {
      statusText = 'Urgent';
      statusColor = Colors.red;
    } else if (progress >= 0.8) {
      statusText = 'Almost There';
      statusColor = Colors.orange;
    } else {
      statusText = 'Active';
      statusColor = Colors.blue;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: statusColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary(context).withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Color _getProgramColor(String type) {
    switch (type.toLowerCase()) {
      case 'savings': return Colors.green;
      case 'investment': return Colors.blue;
      case 'loan': return Colors.purple;
      case 'emergency': return Colors.red;
      default: return const Color(0xFF00BFA5);
    }
  }

  Widget _buildActiveFilterChips() {
    final hasStatusFilter = _filters.statusFilter != ProgramStatusFilter.all;
    final hasTypeFilter = _filters.programType != null;
    
    if (!hasStatusFilter && !hasTypeFilter) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        color: AppColors.background(context),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (hasStatusFilter)
                _buildActiveChip(
                  _filters.statusFilter.name.toUpperCase(),
                  () => setState(() => _filters = _filters.copyWith(statusFilter: ProgramStatusFilter.all)),
                ),
              if (hasStatusFilter && hasTypeFilter) const SizedBox(width: 8),
              if (hasTypeFilter)
                _buildActiveChip(
                  ProgramTypes.getDisplayName(_filters.programType!),
                  () => setState(() => _filters = _filters.copyWith(clearProgramType: true)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onDeleted) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(context),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDeleted,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Shimmer.fromColors(
        baseColor: AppColors.card(context),
        highlightColor: AppColors.background(context),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

class FilterSheet extends StatefulWidget {
  final ProgramFilters filters;
  final Function(ProgramFilters) onFiltersChanged;

  const FilterSheet({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ProgramFilters _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.filters;
  }

  @override
  Widget build(BuildContext context) {
    // Access the modal's internal animation for custom cross-fades/slides
    final animation = ModalRoute.of(context)?.animation;
    
    Widget content = Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header with Title and Reset Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Programs',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary(context),
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final freshFilters = ProgramFilters();
                    setState(() {
                      _currentFilters = freshFilters;
                    });
                    widget.onFiltersChanged(freshFilters);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error(context),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters Content Area
            _buildSection('Status', _buildStatusFilter()),
            const SizedBox(height: 24),
            _buildSection('Program Categories', _buildProgramTypeFilter()),
            const SizedBox(height: 32),
            
            // Primary Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onFiltersChanged(_currentFilters);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (animation == null) return content;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            )),
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statusChip('All', ProgramStatusFilter.all),
        _statusChip('Ongoing', ProgramStatusFilter.ongoing),
        _statusChip('Completed', ProgramStatusFilter.completed),
      ],
    );
  }

  Widget _statusChip(String label, ProgramStatusFilter status) {
    final isSelected = _currentFilters.statusFilter == status;
    final primaryColor = AppColors.primary(context);
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isSelected) {
            _currentFilters = _currentFilters.copyWith(statusFilter: ProgramStatusFilter.all);
          } else {
            _currentFilters = _currentFilters.copyWith(statusFilter: status);
          }
        });
      },
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary(context),
      ),
      backgroundColor: AppColors.card(context),
      selectedColor: primaryColor,
      elevation: isSelected ? 4 : 0,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      pressElevation: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppColors.border(context).withValues(alpha: 0.5),
        ),
      ),
      showCheckmark: false,
    );
  }


  Widget _buildProgramTypeFilter() {
    final programTypes = ['all', ...ProgramTypes.allTypes];
    
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: programTypes.map((type) {
        final isSelected = _currentFilters.programType == type || 
                          (type == 'all' && _currentFilters.programType == null);
        final primaryColor = AppColors.primary(context);
        
        return ChoiceChip(
          label: Text(type == 'all' ? 'All' : ProgramTypes.getDisplayName(type)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (type == 'all') {
                _currentFilters = _currentFilters.copyWith(clearProgramType: true);
              } else {
                // If clicking an already selected chip, toggle it off to 'all'
                if (isSelected) {
                  _currentFilters = _currentFilters.copyWith(clearProgramType: true);
                } else {
                  _currentFilters = _currentFilters.copyWith(programType: type);
                }
              }
            });
          },
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
          backgroundColor: AppColors.card(context),
          selectedColor: primaryColor,
          elevation: isSelected ? 4 : 0,
          shadowColor: primaryColor.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelected ? Colors.transparent : AppColors.border(context).withValues(alpha: 0.5),
            ),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildCompactToggle(String title, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.5),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
        subtitle: Text(
          value ? 'Active' : 'Disabled',
          style: TextStyle(
            fontSize: 12,
            color: value ? AppColors.primary(context) : AppColors.textTertiary(context),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

