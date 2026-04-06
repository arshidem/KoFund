// lib/features/profile/screens/participation_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/features/programs/constants/program_types.dart';
import 'package:kofund/core/skeleton/participation_history_skeleton.dart';
import 'package:kofund/ads/simple_banner_ad.dart';
class ParticipationHistoryScreen extends StatefulWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  State<ParticipationHistoryScreen> createState() =>
      _ParticipationHistoryScreenState();
}

class _ParticipationHistoryScreenState
    extends State<ParticipationHistoryScreen> {
  // REMOVED: final RefreshController _refreshController = RefreshController();
  bool _isRefreshing = false;
  bool _isInitialLoad = true;
  
  @override
  void initState() {
    super.initState();
    _loadParticipationHistory();
  }

  Future<void> _loadParticipationHistory() async {
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.getUserParticipationHistory();
    if (mounted) {
      setState(() {
        _isInitialLoad = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    debugPrint('🔄 Pull to refresh triggered in Participation History');
    
    try {
      await _loadParticipationHistory();
      debugPrint('✅ Participation History refresh completed');
    } catch (e) {
      debugPrint('❌ Participation History refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final participationHistory = profileProvider.participationHistory;

    return GradientSheetScaffold(
      title: 'My Programs',
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _onRefresh,
                ),
                SliverToBoxAdapter(
                  child: _buildContent(profileProvider, participationHistory),
                ),
              ],
            ),
          ),
          // Fixed bottom banner ad
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[900] 
                : Colors.grey[100],
            child: const SimpleBannerAd(),
          ),
        ],
      ),
    );
  }

Widget _buildContent(
  ProfileProvider profileProvider,
  List<Map<String, dynamic>> participationHistory,
) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark; // Add this

  // Show loading skeleton on initial load or when provider is loading
  if (_isInitialLoad || profileProvider.isLoading) {
    return ParticipationHistorySkeleton(
      isDarkMode: isDarkMode,
    );
  }

  if (profileProvider.error != null) {
    return _buildErrorState(profileProvider.error!);
  }

  if (participationHistory.isEmpty) {
    return _buildEmptyState();
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // ✅ Standardized padding
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
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge)),
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
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
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

