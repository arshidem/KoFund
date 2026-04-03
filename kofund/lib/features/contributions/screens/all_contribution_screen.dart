import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/contributions/providers/contribution_provider.dart';
import 'package:kofund/features/contributions/widgets/contribution_tile.dart';

class AllContributionsScreen extends StatefulWidget {
  const AllContributionsScreen({super.key});

  @override
  State<AllContributionsScreen> createState() => _AllContributionsScreenState();
}

class _AllContributionsScreenState extends State<AllContributionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Contributions',
      body: Consumer<ContributionProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () async => provider.refresh(),
            edgeOffset: 8,
            color: AppColors.primary(context),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                    child: _buildSearchBar(context),
                  ),
                ),
                _buildContributionList(provider),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: AppColors.textSecondary(context), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search contributions...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Icon(Icons.close, color: AppColors.textSecondary(context), size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildContributionList(ContributionProvider provider) {
    if (provider.isLoading && provider.contributions.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final filteredList = provider.contributions.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.memberName.toLowerCase().contains(query) ||
          c.programName.toLowerCase().contains(query) ||
          c.paymentMethod.toLowerCase().contains(query);
    }).toList();

    if (filteredList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 80,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty ? 'No contributions yet' : 'No results found',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final contribution = filteredList[index];
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPaddingHorizontal,
            ),
            child: ContributionTile(contribution: contribution),
          );
        },
        childCount: filteredList.length,
      ),
    );
  }
}
