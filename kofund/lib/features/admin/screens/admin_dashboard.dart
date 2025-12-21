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
// 🆕 SIMPLIFIED FILTER ENUMS
enum ProgramStatusFilter {
  all,
  ongoing,
  completed,
  cancelled,
}

// 🆕 SIMPLE FILTER MODEL
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

  // 🆕 SIMPLIFIED FILTER APPLY LOGIC
  List<ProgramModel> _applyFilters(List<ProgramModel> programs) {
    return programs.where((program) {
      // Status Filter
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

      // Program Type Filter
      if (_filters.programType != null && _filters.programType != 'all') {
        if (program.programType != _filters.programType) return false;
      }

      // Monthly Program Filter
      if (_filters.monthlyOnly == true) {
        if (!program.isMonthlyPaymentProgram) return false;
      }

      // Availability Filter
      if (_filters.availableOnly == true) {
        if (!program.canJoin) return false;
      }

      return true;
    }).toList();
  }

  // 🆕 OPEN FILTER SHEET
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

    // Apply search and filters
    List<ProgramModel> filteredPrograms = programProvider.programs;
    
    // Apply search
    if (_searchQuery.isNotEmpty) {
      filteredPrograms = filteredPrograms.where((program) {
        return program.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               program.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               program.location.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Apply filters
    filteredPrograms = _applyFilters(filteredPrograms);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      // 🎯 SMART APP BAR WITH SEARCH BAR
      appBar: AppBar(
        title: const Text('Programs'),
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
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
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
              // FILTER TABS
              _buildFilterTabs(),

              // SEARCH HEADER
              if (_searchQuery.isNotEmpty) _buildSearchHeader(filteredPrograms.length),

              // MAIN CONTENT
              Expanded(
                child: _buildBodyContent(programProvider, filteredPrograms),
              ),
            ],
          ),
        ),
      ),

      // FLOATING ACTION BUTTON ONLY FOR ADMINS
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
      // Search Bar
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.card(context).withOpacity(0.5),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Search Icon with Glass Morphism
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      bottomLeft: Radius.circular(28),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary(context).withOpacity(0.3),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            bottomLeft: Radius.circular(28),
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary(context).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.search,
                          color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  
                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                        letterSpacing: 0.5,
                      ),
                      cursorColor: AppColors.primary(context),
                      cursorWidth: 2,
                      cursorHeight: 18,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 5),
                        hintText: 'Search programs...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary(context).withOpacity(0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.close, 
                                    size: 18, 
                                    color: Theme.of(context).appBarTheme.foregroundColor ?? AppColors.textPrimary(context)
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    FocusScope.of(context).unfocus();
                                  },
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
      
      // Filter Icon with Glass Morphism
      const SizedBox(width: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.card(context).withOpacity(0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.tune, 
                color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white, 
                size: 22
              ),
              onPressed: () => _openFilterSheet(context),
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
  // Show skeleton when loading and no programs to display
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

  // 🆕 SIMPLE FILTER TABS
  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildProgramCard(ProgramModel program, ProgramProvider programProvider, AppAuthProvider authProvider) {
    final hasJoined = programProvider.hasUserJoined(program.programId, authProvider.user!.uid);
    final canJoin = program.canJoin && !hasJoined;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: AppColors.card(context),
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _viewProgramDetails(program),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER WITH TITLE AND THREE-DOT MENU (ADMIN ONLY)
                Row(
                  children: [
                    _buildProgramIcon(program.programType),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        program.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    _buildProgramStatus(program),
                    if (widget.isAdmin) ...[
                      const SizedBox(width: 8),
                      _buildAdminMenu(program, programProvider),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
// Add this after the title row (optional)
if (program.enableAutoReminders)
  Container(
    margin: EdgeInsets.only(top: 4),
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.notifications_active, size: 12, color: Colors.orange),
        SizedBox(width: 4),
        Text(
          'Reminders ON',
          style: TextStyle(
            fontSize: 10,
            color: Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ),
                // DESCRIPTION
                Text(
                  program.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 12),

                // PROGRAM DETAILS
                _buildProgramDetails(program),

                const SizedBox(height: 16),

                // FINANCIAL PROGRESS
                _buildFinancialProgress(program, programProvider),

                const SizedBox(height: 16),

                // ACTION BUTTONS
                _buildActionButtons(program, hasJoined, canJoin, programProvider, authProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

// THREE-DOT MENU FOR ADMIN
Widget _buildAdminMenu(ProgramModel program, ProgramProvider programProvider) {
  return PopupMenuButton<String>(
    icon: Icon(Icons.more_vert, color: AppColors.textSecondary(context)),
    onSelected: (value) {
      if (value == 'edit') {
        _editProgram(program);
      } else if (value == 'delete') {
        _showDeleteConfirmation(program, programProvider);
      } else if (value == 'reminders') {  // 🆕 ADD THIS
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
      PopupMenuItem<String>(  // 🆕 ADD THIS NEW ITEM
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

  Widget _buildProgramIcon(String programType) {
    final iconData = ProgramTypes.getIconData(programType);
    
    return CircleAvatar(
      backgroundColor: AppColors.primary(context).withOpacity(0.12),
      child: Icon(iconData, color: AppColors.primary(context), size: 20),
    );
  }

  Widget _buildProgramStatus(ProgramModel program) {
    Color color;
    String text;

    if (program.isCompleted) {
      color = Colors.grey;
      text = 'Completed';
    } else if (program.isOngoing) {
      color = Colors.green;
      text = 'Ongoing';
    } else if (program.isCancelled) {
      color = Colors.red;
      text = 'Cancelled';
    } else {
      color = AppColors.primary(context);
      text = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProgramDetails(ProgramModel program) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(Icons.calendar_today, 'Date: ${_formatDate(program.programDate)}'),
        _buildDetailRow(Icons.location_on, 'Location: ${program.location}'),
        if (program.suggestedContribution != null && program.suggestedContribution! > 0)
          _buildDetailRow(Icons.attach_money, 'Contribution: ₹${program.suggestedContribution!.toStringAsFixed(2)}'),
        _buildDetailRow(Icons.people,
            'Participants: ${program.currentParticipants}${program.isFixedParticipants ? '/${program.maxParticipants}' : ''}'),
        _buildDetailRow(Icons.category, 'Type: ${ProgramTypes.getDisplayName(program.programType)}'),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DASHBOARD-STYLE FINANCIAL PROGRESS
  Widget _buildFinancialProgress(ProgramModel program, ProgramProvider programProvider) {
    final target = program.totalProgramAmount ?? 0.0;
    
    return StreamBuilder<double>(
      stream: programProvider.streamProgramTotalContributions(program.programId),
      builder: (context, contribSnap) {
        final collected = contribSnap.data ?? 0.0;
        final rawProgress = target > 0 ? (collected / target) : 0.0;
        final progress = (rawProgress.clamp(0.0, 1.0) as double);

        return Column(
          children: [
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.progressBackground(context),
                color: AppColors.progressFill(context),
              ),
            ),
            const SizedBox(height: 8),
            
            // Progress Text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "₹${collected.toStringAsFixed(2)} / ₹${target.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  "${(progress * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary(context),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(ProgramModel program, bool hasJoined, bool canJoin,
      ProgramProvider programProvider, AppAuthProvider authProvider) {
    return Row(
      children: [
        // View Details Button
        Expanded(
          child: ElevatedButton(
            onPressed: () => _viewProgramDetails(program),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.card(context),
              foregroundColor: AppColors.textPrimary(context),
              side: BorderSide(
                color: AppColors.border(context),
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
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: () => _leaveProgram(program, programProvider, authProvider),
          ),
        ] else ...[
          Expanded(
            child: ElevatedButton(
              onPressed: canJoin ? () => _joinProgram(program, programProvider, authProvider) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                !canJoin && program.isFixedParticipants && program.currentParticipants >= program.maxParticipants
                    ? 'Full'
                    : 'Join Now'
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ADMIN FUNCTIONS
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

// 🆕 FIXED FILTER SHEET - NO OVERFLOW
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
              // DRAG HANDLE
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // TITLE
              Text(
                'Quick Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 20),

              // Program Type Filter - COMPACT VERSION
              _buildSection(
                'Program Type',
                _buildProgramTypeFilter(),
              ),

              const SizedBox(height: 16),

              // Quick Toggles - COMPACT VERSION
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

              // Action Buttons
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
              const SizedBox(height: 10), // BOTTOM PADDING FOR SAFE AREA
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
    // COMPACT PROGRAM TYPE FILTER - FEWER ITEMS PER ROW
    final programTypes = ['all', ...ProgramTypes.allTypes];
    
    return Wrap(
      spacing: 6, // REDUCED SPACING
      runSpacing: 6, // REDUCED RUN SPACING
      children: programTypes.map((type) {
        final isSelected = _currentFilters.programType == type || 
                          (type == 'all' && _currentFilters.programType == null);
        return FilterChip(
          label: Text(
            type == 'all' ? 'All Types' : ProgramTypes.getDisplayName(type),
            style: TextStyle(
              fontSize: 12, // SMALLER FONT
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

  // COMPACT TOGGLE VERSION
  Widget _buildCompactToggle(String title, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true, // MAKES IT MORE COMPACT
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