// lib/features/profile/screens/participation_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/widgets/loading_indicator.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kofund/core/skeleton/participation_history_skeleton.dart';

class ParticipationHistoryScreen extends StatefulWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  State<ParticipationHistoryScreen> createState() =>
      _ParticipationHistoryScreenState();
}

class _ParticipationHistoryScreenState
    extends State<ParticipationHistoryScreen> {
  final RefreshController _refreshController = RefreshController();
  bool _isRefreshing = false;
  
  @override
  void initState() {
    super.initState();
    _loadParticipationHistory();
  }

  Future<void> _loadParticipationHistory() async {
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.getUserParticipationHistory();
  }

  void _onRefresh() async {
    debugPrint('🔄 Pull to refresh triggered in Participation History');
    
    if (!mounted) return;
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      await _loadParticipationHistory();
      if (mounted) {
        _refreshController.refreshCompleted();
      }
      debugPrint('✅ Participation History refresh completed');
    } catch (e) {
      if (mounted) {
        _refreshController.refreshFailed();
      }
      debugPrint('❌ Participation History refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final participationHistory = profileProvider.participationHistory;

    return Scaffold(
      backgroundColor: AppColors.background(context),
appBar: AppBar(
  toolbarHeight: 80,
  title: const Text(
    'My Programs', // Updated with TextStyle
    style: TextStyle(
      color: Colors.white, // Changed to white
      fontSize: 18, // Added from Members app bar
      fontWeight: FontWeight.w600, // Added from Members app bar
    ),
  ),
  centerTitle: true,
  leading: IconButton(
    icon: const Icon(
      Icons.arrow_back,
      color: Colors.white, // Changed to white
    ),
    onPressed: () => Navigator.pop(context),
  ),
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
          refreshingText: '',
          completeText: 'Refresh complete',
          failedText: 'Refresh failed',
          idleIcon: Icon(Icons.arrow_downward, color: AppColors.textSecondary(context)),
          releaseIcon: Icon(Icons.arrow_upward, color: AppColors.primary(context)),
          refreshingIcon: SizedBox.shrink(),
          completeIcon: Icon(Icons.check, color: Colors.green),
          failedIcon: Icon(Icons.error, color: Colors.red),
        ),
        child: _isRefreshing
          ? ParticipationHistorySkeleton(isDarkMode: Theme.of(context).brightness == Brightness.dark)
          : _buildContent(profileProvider, participationHistory),
      ),
    );
  }

  Widget _buildContent(
    ProfileProvider profileProvider,
    List<Map<String, dynamic>> participationHistory,
  ) {
    if (profileProvider.isLoading) {
      return ParticipationHistorySkeleton(isDarkMode: Theme.of(context).brightness == Brightness.dark);
    }

    if (profileProvider.error != null) {
      return _buildErrorState(profileProvider.error!);
    }

    if (participationHistory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8), // ✅ Padding 8px only
      itemCount: participationHistory.length,
      itemBuilder: (context, index) {
        final participation = participationHistory[index];
        return _buildParticipationCard(participation);
      },
    );
  }

  Widget _buildParticipationCard(Map<String, dynamic> participation) {
    final programTitle = participation['programTitle'] ?? 'Unnamed Program';
    final programType = participation['programType'] ?? ProgramTypes.general;
    final joinedAt = _parseDate(participation['joinedAt']);
    final hasPaid = participation['hasPaidContribution'] ?? false;
    final contributionPaid = (participation['contributionPaid'] ?? 0).toDouble();
    final suggestedContribution = (participation['suggestedContribution'] ?? 0).toDouble();
    final progressPercentage = (participation['progressPercentage'] ?? 0).toDouble();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildProgramIcon(programType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(joinedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasPaid 
                        ? AppColors.primary(context).withValues(alpha: 0.1) // ✅ Use primary color
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasPaid 
                          ? AppColors.primary(context) // ✅ Use primary color
                          : Colors.orange,
                    ),
                  ),
                  child: Text(
                    hasPaid ? 'Paid' : 'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasPaid 
                          ? AppColors.primary(context) // ✅ Use primary color
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Program Type
            _buildDetailRow('Type', ProgramTypes.getDisplayName(programType)),

            // Contribution info
            if (suggestedContribution > 0) ...[
              const SizedBox(height: 8),
              _buildContributionInfo(
                contributionPaid,
                suggestedContribution,
                hasPaid,
                progressPercentage,
              ),
            ] else ...[
              const SizedBox(height: 8),
              _buildNoContributionInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramIcon(String programType) {
    final iconData = ProgramTypes.getIconData(programType);

    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primary(context).withValues(alpha: 0.1),
      child: Icon(iconData, color: AppColors.primary(context), size: 20),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionInfo(
    double paid,
    double suggested,
    bool hasPaid,
    double progressPercentage,
  ) {
    final primaryColor = AppColors.primary(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Contribution Progress',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
              ),
            ),
            Text(
              '${progressPercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasPaid ? primaryColor : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '₹${paid.toStringAsFixed(2)} / ₹${suggested.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: hasPaid ? primaryColor : Colors.orange,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progressPercentage / 100,
          backgroundColor: AppColors.border(context),
          color: hasPaid ? primaryColor : Colors.orange, // ✅ Primary color for completed
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasPaid ? 'Fully Paid' : 'Payment Pending',
              style: TextStyle(
                fontSize: 10,
                color: hasPaid ? primaryColor : Colors.orange, // ✅ Primary color for paid
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!hasPaid)
              Text(
                '₹${(suggested - paid).toStringAsFixed(2)} remaining',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary(context),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoContributionInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.info, size: 16, color: AppColors.textSecondary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No contribution required for this program',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_note, size: 80, color: AppColors.textSecondary(context)),
              const SizedBox(height: 16),
              Text(
                'No Program Participations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'You haven\'t joined any programs yet. Start participating in community programs to see them here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to programs screen
                  // Navigator.pushNamed(context, '/programs');
                },
                icon: const Icon(Icons.explore),
                label: const Text('Browse Programs'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Unable to Load Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadParticipationHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is DateTime) {
      return date;
    } else {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

