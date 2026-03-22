import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import '../providers/program_provider.dart';
import '../models/program_model.dart';
import '../constants/program_types.dart';
import 'create_program_screen.dart';
import 'program_details_screen.dart';
import 'edit_program_screen.dart';
import 'program_reminder_screen.dart';
import 'package:flutter/services.dart';
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
  }) {
    return ProgramFilters(
      statusFilter: statusFilter ?? this.statusFilter,
      programType: programType ?? this.programType,
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

Future<void> _loadPrograms() async {
  final authProvider = context.read<AppAuthProvider>();
  final programProvider = context.read<ProgramProvider>();
  
  if (authProvider.user?.communityId != null) {
    await programProvider.loadCommunityPrograms(authProvider.user!.communityId!);
    await programProvider.loadMyParticipations(
      authProvider.user!.uid, 
      authProvider.user!.communityId!,
    );
    
    // ✅ Call sync again to ensure it's done
    // Use unawaited so it doesn't block the UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await programProvider.syncAllProgramsStatus();
    });
  }
}

  void _onRefresh() async {
    debugPrint('🔄 DEBUG: Pull to refresh triggered in Programs');
    
    try {
      await _loadPrograms();
      _refreshController.refreshCompleted();
      debugPrint('✅ DEBUG: Programs refresh completed successfully');
    } catch (e) {
      _refreshController.refreshFailed();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FilterSheet(
          filters: _filters,
          onFiltersChanged: (newFilters) {
            setState(() {
              _filters = newFilters;
            });
          },
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
    
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPrimaryGradientStart : AppColors.lightPrimaryGradientStart,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          _buildSliverAppBar(context),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await _loadPrograms();
            },
          ),
          // 📌 STICKY ROUNDED HEADER - Pins below the main app bar
          SliverAppBar(
            toolbarHeight: 0,
            expandedHeight: 20,
            pinned: true,
            elevation: 0,
            primary: false,
            backgroundColor: Colors.transparent, // Show gradient behind corners
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: AppColors.background(context),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
              ),
            ),
          ),
          // Body content with background color
          _buildBodyContent(programProvider, filteredPrograms),
          // Fill remaining space with background color to hide teal at the bottom
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(color: AppColors.background(context)),
          ),
        ],
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
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent, // Let flexibleSpace handle color
      automaticallyImplyLeading: false,
      // Dynamic Title using flexibleSpace for scaling effect
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double top = constraints.biggest.height;
          // Calculate scale factor (0.0 to 1.0)
          // Expanded is 220, Collapsed is toolbarHeight (56) + bottomHeight (84) = 140
          final double minHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
          final double maxHeight = 220.0;
          final double currentHeight = top;
          
          // Normalized progress: 0.0 at collapsed (140), 1.0 at expanded (220)
          final double progress = ((currentHeight - 140) / (maxHeight - 140)).clamp(0.0, 1.0);
          
          // Font size: 32 at expanded, 20 at collapsed
          final double fontSize = 20 + (6 * progress); // 20 to 26 scaling
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
                centerTitle: true,
                titlePadding: EdgeInsets.only(
                  bottom: 84 + (24 * progress), 
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
        preferredSize: const Size.fromHeight(84),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildModernSearchBar(),
        ),
      ),
    );
  }

Widget _buildModernSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                // 🔍 SEARCH ICON
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                
                // 📝 SEARCH FIELD
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    cursorColor: Colors.white,
                    cursorWidth: 2,
                    cursorHeight: 20,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      hintText: 'Search programs...',
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 0),
                              child: Container(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    FocusScope.of(context).unfocus();
                                  },
                                ),
                              ),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // ⚙️ FILTER ICON
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.transparent,
          ),
          child: Material(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openFilterSheet(context),
              child: const Center(
                child: Icon(
                  Icons.tune,
                  color: Colors.white,
                  size: 22,
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
              borderRadius: BorderRadius.circular(12),
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
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Container(
        color: bgColor,
        child: ProgramListSkeleton(
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
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

  return SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final program = displayedPrograms[index];
        return Container(
          color: bgColor,
          child: _buildProgramCard(program, programProvider, context.read<AppAuthProvider>()),
        );
      },
      childCount: displayedPrograms.length,
    ),
  );
}

  Widget _buildEmptyState() {
    final isAdmin = widget.isAdmin;

    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          if (_searchQuery.isNotEmpty)
            Icon(
              Icons.search_off, 
              size: 64, 
              color: const Color(0xFF00BFA5).withValues(alpha: 0.5)
            )
          else
            Icon(
              Icons.event_note_rounded,
              size: 64,
              color: const Color(0xFF00BFA5).withValues(alpha: 0.5),
            ),
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
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Clear Search'),
            ),
          ],
        ],
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
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2F2F).withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(28),
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
          borderRadius: BorderRadius.circular(28),
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
                                (program.maxParticipants == null ||
                                    program.maxParticipants! > totalParticipants));

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
                                    borderRadius: BorderRadius.circular(16),
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
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 500),
                                          height: 8,
                                          width: constraints.maxWidth * progress,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [programColor, programColor.withValues(alpha: 0.7)],
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
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
                                      '₦${collectedAmount.toInt()}',
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: hasJoined 
                                    ? () => _viewProgramDetails(program)
                                    : (canJoin ? () => _joinProgram(program, programProvider, authProvider) : null),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: hasJoined || canJoin ? programColor : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(12),
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
                                          hasJoined ? 'DETAILS' : (canJoin ? 'JOIN NOW' : 'FULL'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
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
    icon: Icon(Icons.more_vert, color: AppColors.textSecondary(context)),
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
      PopupMenuItem<String>(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit, color: AppColors.primary(context)),
            const SizedBox(width: 8),
            Text('Edit Program'),
          ],
        ),
      ),
      // PopupMenuItem<String>(
      //   value: 'reminders',
      //   child: Row(
      //     children: [
      //       Icon(Icons.notifications_active, color: Colors.orange),
      //       const SizedBox(width: 8),
      //       Text('Set Reminders'),
      //     ],
      //   ),
      // ),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Program'),
          ],
        ),
      ),
    ],
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

  void _showDeleteConfirmation(ProgramModel program, ProgramProvider programProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Program?'),
        content: Text('Are you sure you want to delete "${program.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context)))
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProgram(program, programProvider);
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Program?'),
        content: Text('Are you sure you want to leave ${program.title}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave', style: TextStyle(color: Colors.red))),
        ],
      ),
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
}

class FilterSheet extends StatefulWidget {
  final ProgramFilters filters;
  final Function(ProgramFilters) onFiltersChanged;

  const FilterSheet({
    Key? key,
    required this.filters,
    required this.onFiltersChanged,
  }) : super(key: key);

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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Text(
                'Quick Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 20),

               _buildSection(
                'Program Status',
                _buildStatusFilter(),
              ),

              const SizedBox(height: 20),

              _buildSection(
                'Program Type',
                _buildProgramTypeFilter(),
              ),

              const SizedBox(height: 16),

              _buildSection(
                'Filters',
                Column(
                  children: [
                    _buildCompactToggle(
                      'Monthly Programs Only',
                      _currentFilters.monthlyOnly ?? false,
                      (value) => setState(() {
                        _currentFilters = _currentFilters.copyWith(monthlyOnly: value);
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildCompactToggle(
                      'Available to Join Only',
                      _currentFilters.availableOnly ?? false,
                      (value) => setState(() {
                        _currentFilters = _currentFilters.copyWith(availableOnly: value);
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onFiltersChanged(ProgramFilters());
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary(context),
                        side: BorderSide(color: AppColors.primary(context)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Clear All"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onFiltersChanged(_currentFilters);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Apply Filters"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
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
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppColors.textPrimary(context),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilters = _currentFilters.copyWith(statusFilter: status);
        });
      },
      backgroundColor: AppColors.card(context),
      selectedColor: const Color(0xFF00BFA5),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppColors.border(context).withValues(alpha: 0.5),
        ),
      ),
    );
  }


  Widget _buildProgramTypeFilter() {
    final programTypes = ['all', ...ProgramTypes.allTypes];
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: programTypes.map((type) {
        final isSelected = _currentFilters.programType == type || 
                          (type == 'all' && _currentFilters.programType == null);
        return FilterChip(
          label: Text(
            type == 'all' ? 'All Types' : ProgramTypes.getDisplayName(type),
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : AppColors.textPrimary(context),
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _currentFilters = _currentFilters.copyWith(
                programType: selected ? (type == 'all' ? null : type) : null,
              );
            });
          },
          backgroundColor: AppColors.card(context),
          selectedColor: AppColors.primary(context),
          checkmarkColor: Colors.white,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _buildCompactToggle(String title, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary(context),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary(context),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }
}

