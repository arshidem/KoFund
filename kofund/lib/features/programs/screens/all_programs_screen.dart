import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
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
import 'dart:ui';
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
    }
  }

  void _onRefresh() async {
    print('🔄 DEBUG: Pull to refresh triggered in Programs');
    
    try {
      await _loadPrograms();
      _refreshController.refreshCompleted();
      print('✅ DEBUG: Programs refresh completed successfully');
    } catch (e) {
      _refreshController.refreshFailed();
      print('❌ DEBUG: Programs refresh failed: $e');
    }
  }

  List<ProgramModel> _applyFilters(List<ProgramModel> programs) {
    return programs.where((program) {
      if (_filters.statusFilter != ProgramStatusFilter.all) {
        switch (_filters.statusFilter) {
          case ProgramStatusFilter.ongoing:
            if (!program.isOngoing) return false;
            break;
          case ProgramStatusFilter.completed:
            if (!program.isCompleted) return false;
            break;
          case ProgramStatusFilter.cancelled:
            if (!program.isCancelled) return false;
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
    
    filteredPrograms = _applyFilters(filteredPrograms);

    return Scaffold(
      backgroundColor: AppColors.background(context),
appBar: AppBar(
  title: Text(
    'Programs',
    style: TextStyle(color: Colors.white), // Explicit text style
  ),
  centerTitle: true,
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white, // Change this to white70
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
    ),
  ),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(50),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: _buildModernSearchBar(),
    ),
  ),
),

      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        enablePullDown: true,
        enablePullUp: false,
        physics: const BouncingScrollPhysics(),
        header: ClassicHeader(
          idleText: 'Pull down to refresh',
          releaseText: 'Release to refresh',
          refreshingText: 'Refreshing programs...',
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
        child: SafeArea(
          child: Column(
            children: [
              _buildFilterTabs(),
              if (_searchQuery.isNotEmpty) _buildSearchHeader(filteredPrograms.length),
              Expanded(
                child: _buildBodyContent(programProvider, filteredPrograms),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _navigateToCreateProgram(context),
              backgroundColor: AppColors.primary(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
                color: Colors.white.withOpacity(0.5),
                width: 1.5, // Increased border width
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              color: Colors.transparent, // Transparent background
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Row(
                  children: [
                    // 🔍 SEARCH ICON - Transparent with white border
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.transparent, // Transparent background
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 0, // Same border width
                        ),
                      ),
                      child: Icon(
                        Icons.search,
                        color: Colors.white, // White icon
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
                          color: Colors.white, // Always white text
                          letterSpacing: 0.5,
                        ),
                        cursorColor: Colors.white, // White cursor
                        cursorWidth: 2,
                        cursorHeight: 20,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          hintText: 'Search programs...',
                          hintStyle: const TextStyle(
                            color: Colors.white70, // White hint with 70% opacity
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
          ),
        ),
        
        const SizedBox(width: 8),
        
        // ⚙️ FILTER ICON - Transparent with white border
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5, // Same border width
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.transparent, // Transparent background
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openFilterSheet(context),
                  child: const Center(
                    child: Icon(
                      Icons.tune,
                      color: Colors.white, // White icon
                      size: 22,
                    ),
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
      color: AppColors.primary(context).withOpacity(0.06),
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
              color: AppColors.primary(context).withOpacity(0.18),
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
  if (programProvider.isLoading && displayedPrograms.isEmpty) {
    return ProgramListSkeleton(
      isDarkMode: Theme.of(context).brightness == Brightness.dark,
    );
  }

  if (programProvider.error != null && displayedPrograms.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
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
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  return displayedPrograms.isEmpty
      ? _buildEmptyState()
      : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: displayedPrograms.length,
          itemBuilder: (context, index) {
            final program = displayedPrograms[index];
            return _buildProgramCard(program, programProvider, context.read<AppAuthProvider>());
          },
        );
}

  Widget _buildEmptyState() {
    final isAdmin = widget.isAdmin;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        if (_searchQuery.isNotEmpty)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: 1.0,
            child: Icon(
              Icons.search_off, 
              size: 64, 
              color: AppColors.primary(context).withOpacity(0.5)
            ),
          )
        else
          Icon(
            Icons.event,
            size: 64,
            color: AppColors.primary(context).withOpacity(0.5),
          ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _searchQuery.isNotEmpty ? 'No results found' : 'No Programs Available',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.primary(context).withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _searchQuery.isNotEmpty 
                ? 'Try adjusting your search or filters'
                : isAdmin
                    ? 'Create the first program for your community.'
                    : 'No programs available yet. Check back later.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Clear Search'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.only(right: 16, left: 16, top: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _tab("All", _filters.statusFilter == ProgramStatusFilter.all,
              () => _setFilter(ProgramStatusFilter.all)),
          _tab("Ongoing", _filters.statusFilter == ProgramStatusFilter.ongoing,
              () => _setFilter(ProgramStatusFilter.ongoing)),
          _tab("Completed", _filters.statusFilter == ProgramStatusFilter.completed,
              () => _setFilter(ProgramStatusFilter.completed)),
          _tab("Cancelled", _filters.statusFilter == ProgramStatusFilter.cancelled,
              () => _setFilter(ProgramStatusFilter.cancelled)),
        ],
      ),
    );
  }

  Widget _tab(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textPrimary(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _setFilter(ProgramStatusFilter filter) {
    setState(() {
      _filters = _filters.copyWith(statusFilter: filter);
    });
  }

// Replace the _buildProgramCard method with this corrected version

Widget _buildProgramCard(
  ProgramModel program,
  ProgramProvider programProvider,
  AppAuthProvider authProvider,
) {
  final hasJoined =
      programProvider.hasUserJoined(program.programId, authProvider.user!.uid);
  final canJoin = program.canJoin && !hasJoined;

  return Consumer<ParticipantProvider>(
    builder: (context, participantProvider, _) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Material(
          color: AppColors.card(context),
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _viewProgramDetails(program),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: StreamBuilder<double>(
                stream: programProvider
                    .streamProgramTotalContributions(program.programId),
                builder: (context, contribSnap) {
                  final collectedAmount = contribSnap.data ?? 0.0;

                  final suggestedAmount = program.suggestedContribution ?? 0.0;
                  
                  // Get participant count from ParticipantProvider stream
                  return StreamBuilder<List<ParticipantModel>>(
                    stream: participantProvider.streamProgramParticipants(program.programId),
                    builder: (context, participantSnapshot) {
                      final participants = participantSnapshot.data ?? [];
                      final totalParticipants = participants.length;
                      final maxParticipants = program.maxParticipants ?? 0;

                      final participantCount = program.isFixedParticipants
                          ? maxParticipants
                          : totalParticipants;

                      final programAmount = suggestedAmount > 0
                          ? suggestedAmount * participantCount
                          : 0.0;

                      final progress =
                          programAmount > 0 ? collectedAmount / programAmount : 0.0;

                      final daysLeft =
                          program.programDate.difference(DateTime.now()).inDays;

                      final isUrgent = daysLeft <= 3 && daysLeft >= 0;
                      final programColor =
                          _getProgramColor(program.programType);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ───────── HEADER ─────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: programColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _getProgramIcon(program.programType),
                                  color: programColor,
                                  size: 26,
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            program.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  AppColors.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        if (widget.isAdmin)
                                          _buildAdminMenu(
                                              program, programProvider),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        _buildProgramStatus(program),

                                        if (program.enableAutoReminders) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.blue.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.blue
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: const Text(
                                              'Reminders',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ───────── DESCRIPTION ─────────
                          Text(
                            program.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textSecondary(context),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // ───────── PROGRESS ─────────
                     // ───────── PROGRESS ─────────
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'Progress',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    Text(
      '${(progress * 100).toStringAsFixed(1)}%',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: programColor,
      ),
    ),
  ],
),

const SizedBox(height: 8),

// 🔧 UPDATED PROGRESS BAR WITH GRAY 300 BACKGROUND
Container(
  height: 7,
  width: double.infinity,
  decoration: BoxDecoration(
    color: Colors.grey[300], // ← CHANGED TO GRAY 300
    borderRadius: BorderRadius.circular(4),
  ),
  child: FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: progress.clamp(0.0, 1.0),
    child: Container(
      decoration: BoxDecoration(
        color: programColor,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  ),
),

                          const SizedBox(height: 18),

                          // ───────── STATS ─────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem(
                                icon: Icons.currency_rupee,
                                value:
                                    '₹${collectedAmount.toStringAsFixed(0)}',
                                label: 'Collected',
                                color: Colors.green,
                              ),
                              _buildStatItem(
                                icon: Icons.track_changes,
                                value:
                                    '₹${programAmount.toStringAsFixed(0)}',
                                label: 'Target',
                                color: AppColors.primary(context),
                              ),
                              _buildStatItem(
                                icon: Icons.people,
                                value: '$totalParticipants',
                                label: 'Members',
                                color: Colors.blue,
                              ),
                              _buildStatItem(
                                icon: Icons.schedule,
                                value: '$daysLeft',
                                label: 'Days',
                                color:
                                    isUrgent ? Colors.red : Colors.orange,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ───────── ACTIONS ─────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _viewProgramDetails(program),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('View Details'),
                                ),
                              ),

                              const SizedBox(width: 10),

                              if (hasJoined)
                                IconButton(
                                  icon: const Icon(Icons.exit_to_app,
                                      color: Colors.red),
                                  onPressed: () => _leaveProgram(
                                      program,
                                      programProvider,
                                      authProvider),
                                )
                              else
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: canJoin
                                        ? () => _joinProgram(
                                            program,
                                            programProvider,
                                            authProvider)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      !canJoin &&
                                              program.isFixedParticipants &&
                                              totalParticipants >=
                                                  maxParticipants
                                          ? 'Full'
                                          : 'Join Now',
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
              ),
            ),
          ),
        ),
      );
    },
  );
}
Widget _buildProgramStatus(ProgramModel program) {
  Color color;
  String text;

  if (!program.canJoin) {
    color = Colors.red;
    text = 'Closed';
  } else if (program.isFixedParticipants &&
      program.currentParticipants >= program.maxParticipants) {
    color = Colors.orange;
    text = 'Full';
  } else {
    color = Colors.green;
    text = 'Open';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}


  Color _getProgramColor(String type) {
    switch (type.toLowerCase()) {
      case 'savings':
        return Colors.green;
      case 'investment':
        return Colors.blue;
      case 'loan':
        return Colors.purple;
      case 'emergency':
        return Colors.red;
      default:
        return AppColors.primary(context);
    }
  }

  IconData _getProgramIcon(String type) {
    switch (type.toLowerCase()) {
      case 'savings':
        return Icons.account_balance_wallet;
      case 'investment':
        return Icons.trending_up;
      case 'loan':
        return Icons.currency_exchange;
      case 'emergency':
        return Icons.medical_services;
      default:
        return Icons.assignment;
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onPressed,
    required Color programColor,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? programColor : AppColors.surface(context),
        foregroundColor: isPrimary ? Colors.white : AppColors.textPrimary(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary 
              ? BorderSide.none 
              : BorderSide(color: AppColors.border(context)),
        ),
        elevation: isPrimary ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ProgramModel program, double progress, int daysLeft) {
    String statusText;
    Color statusColor;
    
    if (progress >= 1.0) {
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
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

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
      PopupMenuItem<String>(
        value: 'reminders',
        child: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Set Reminders'),
          ],
        ),
      ),
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
        SnackbarHelper.showInfo(context, 'Left ${program.title}');
      } catch (e) {
        SnackbarHelper.showError(context, 'Failed to leave: $e');
      }
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
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
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
          activeColor: AppColors.primary(context),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }
}