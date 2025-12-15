// // Admin dashboard 
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../routing/route_names.dart';
// import '../../auth/providers/app_auth_provider.dart';
// import '../../community/providers/community_provider.dart';

// class AdminDashboard extends StatefulWidget {
//   const AdminDashboard({super.key});

//   @override
//   State<AdminDashboard> createState() => _AdminDashboardState();
// }

// class _AdminDashboardState extends State<AdminDashboard> {
//   @override
//   void initState() {
//     super.initState();
//     _loadCommunity();
//   }

//   void _loadCommunity() {
//     final authProvider = context.read<AppAuthProvider>();
//     final communityProvider = context.read<CommunityProvider>();
    
//     if (authProvider.user?.communityId != null) {
//       communityProvider.loadCommunity(authProvider.user!.communityId!);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = context.read<AppAuthProvider>().user;
//     final communityProvider = context.read<CommunityProvider>();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Admin Dashboard'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () {
//               context.read<AppAuthProvider>().signOut();
//             },
//           ),
//         ],
//       ),
//       body: StreamBuilder<CommunityModel?>(
//         stream: communityProvider.getCommunityStream(user?.communityId ?? ''),
//         builder: (context, snapshot) {
//           final community = snapshot.data;

//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (community == null) {
//             return const Center(child: Text('Community not found'));
//           }

//           return Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           community.name,
//                           style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                                 fontWeight: FontWeight.bold,
//                               ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(community.description),
//                         const SizedBox(height: 16),
//                         Row(
//                           children: [
//                             _InfoChip(
//                               icon: Icons.code,
//                               label: 'Join Code: ${community.code}',
//                             ),
//                             const SizedBox(width: 12),
//                             _InfoChip(
//                               icon: Icons.people,
//                               label: '${community.memberCount} members',
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 Expanded(
//                   child: GridView(
//                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: 2,
//                       crossAxisSpacing: 16,
//                       mainAxisSpacing: 16,
//                       childAspectRatio: 1.2,
//                     ),
//                     children: [
//                       _AdminTile(
//                         icon: Icons.person_add,
//                         title: 'Approval Requests',
//                         subtitle: 'Manage join requests',
//                         color: Colors.orange,
//                         badgeCount: _getPendingRequestCount(communityProvider),
//                         onTap: () {
//                           Navigator.pushNamed(context, RouteNames.approvalRequests);
//                         },
//                       ),
//                       _AdminTile(
//                         icon: Icons.people,
//                         title: 'Members',
//                         subtitle: 'View all members',
//                         color: Colors.blue,
//                         onTap: () {
//                           // Navigate to members screen
//                         },
//                       ),
//                       _AdminTile(
//                         icon: Icons.settings,
//                         title: 'Settings',
//                         subtitle: 'Community settings',
//                         color: Colors.grey,
//                         onTap: () {
//                           // Navigate to settings
//                         },
//                       ),
//                       _AdminTile(
//                         icon: Icons.analytics,
//                         title: 'Analytics',
//                         subtitle: 'View insights',
//                         color: Colors.green,
//                         onTap: () {
//                           // Navigate to analytics
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   int _getPendingRequestCount(CommunityProvider communityProvider) {
//     // This would typically come from a stream or provider state
//     return 0; // Implement based on your data
//   }
// }

// class _InfoChip extends StatelessWidget {
//   final IconData icon;
//   final String label;

//   const _InfoChip({required this.icon, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Chip(
//       avatar: Icon(icon, size: 16),
//       label: Text(label),
//     );
//   }
// }

// class _AdminTile extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String subtitle;
//   final Color color;
//   final int badgeCount;
//   final VoidCallback onTap;

//   const _AdminTile({
//     required this.icon,
//     required this.title,
//     required this.subtitle,
//     required this.color,
//     this.badgeCount = 0,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 4,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Stack(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(icon, size: 40, color: color),
//                   const SizedBox(height: 12),
//                   Text(
//                     title,
//                     style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                           fontWeight: FontWeight.bold,
//                         ),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     subtitle,
//                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: Colors.grey[600],
//                         ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ],
//               ),
//             ),
//             if (badgeCount > 0)
//               Positioned(
//                 top: 8,
//                 right: 8,
//                 child: Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: const BoxDecoration(
//                     color: Colors.red,
//                     shape: BoxShape.circle,
//                   ),
//                   child: Text(
//                     badgeCount.toString(),
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/program_model.dart';
import '../../../contributions/providers/contribution_provider.dart';
import '../../../contributions/models/contribution_model.dart';
import '../../../auth/providers/app_auth_provider.dart';
import '../../../../core/constants/app_colors.dart'; // Add this import
import 'package:kofund/core/services/user_service.dart'; // Add this import

class ProgramContributionsTab extends StatefulWidget {
  final ProgramModel program;

  const ProgramContributionsTab({super.key, required this.program});

  @override
  State<ProgramContributionsTab> createState() => _ProgramContributionsTabState();
}

class _ProgramContributionsTabState extends State<ProgramContributionsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMethod = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Check if current user is admin
  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    
    if (currentUser == null) return false;
    
    // 1. Program creator is always admin
    if (currentUser.uid == widget.program.createdBy) {
      return true;
    }
    
    // 2. User with 'admin' role
    if (currentUser.role == 'admin') {
      return true;
    }
    
    // 3. User with isAdmin flag and approved
    if (currentUser.isAdmin == true && currentUser.isApproved == true) {
      return true;
    }
    
    return false;
  }

// In your build method or state
Future<String> _getUserName(String userId, BuildContext context) async {
  try {
    final userService = UserService();
    final user = await userService.getUserById(userId);
    
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    
    // Fallback to email if name not available
    if (user != null && user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    }
    
    return 'User $userId';
  } catch (e) {
    print('Error fetching user name: $e');
    return 'User $userId';
  }
}

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin(context);
    
    return Column(
      children: [
        // Contribution Summary Card (Progress Bar)
        _buildContributionSummary(context),
        
        // Search and Filter Bar
        _buildSearchFilterBar(context),
        
        // Contributions List
        Expanded(
          child: StreamBuilder<List<ContributionModel>>(
            stream: Provider.of<ContributionProvider>(context, listen: false)
                .streamProgramContributions(widget.program.programId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary(context),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error,
                        color: AppColors.error(context),
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading contributions',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final contributions = snapshot.data ?? [];
              final filteredContributions = _filterContributions(contributions);

              if (filteredContributions.isEmpty) {
                return _buildEmptyState(contributions.isEmpty, context);
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                itemCount: filteredContributions.length,
                itemBuilder: (context, index) {
                  final contribution = filteredContributions[index];
                  return _buildContributionCard(contribution, context, isAdmin);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContributionSummary(BuildContext context) {
    return StreamBuilder<double>(
      stream: Provider.of<ContributionProvider>(context, listen: false)
          .streamProgramTotalContributions(widget.program.programId),
      builder: (context, totalSnapshot) {
        final totalCollected = totalSnapshot.data ?? 0.0;
        final totalExpected = widget.program.estimatedTotalAmount;
        final progressPercentage = widget.program.calculateProgress(totalCollected);

        return StreamBuilder<List<ContributionModel>>(
          stream: Provider.of<ContributionProvider>(context, listen: false)
              .streamProgramContributions(widget.program.programId),
          builder: (context, contributionsSnapshot) {
            final contributions = contributionsSnapshot.data ?? [];
            final totalCount = contributions.length;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ───────────────── Header ─────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Contributions Overview",
                            style: TextStyle(
                              color: AppColors.textCards(context).withOpacity(0.9),
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.payments,
                                color: AppColors.textCards(context),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$totalCount contributions',
                                style: TextStyle(
                                  color: AppColors.textCards(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                     
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// ───────────────── Amount ─────────────────
                  Text(
                    "₹${totalCollected.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: AppColors.textCards(context),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (totalExpected > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "of ₹${totalExpected.toStringAsFixed(0)} expected",
                        style: TextStyle(
                          color: AppColors.textCards(context).withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  /// ───────────────── Progress Bar ─────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalExpected > 0 ? totalCollected / totalExpected : 0,
                      minHeight: 6,
                      backgroundColor: AppColors.textCards(context).withOpacity(0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textCards(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// ───────────────── Progress Info ─────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progressPercentage.toStringAsFixed(1)}% collected',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textCards(context).withOpacity(0.85),
                        ),
                      ),
                      if (totalExpected > totalCollected)
                        Text(
                          '₹${(totalExpected - totalCollected).toStringAsFixed(0)} remaining',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textCards(context).withOpacity(0.85),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

Widget _buildSearchFilterBar(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(
      children: [
        // Search Field - Takes most of the space
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contributions...',
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.textSecondary(context),
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.border(context),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.border(context),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary(context),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 13,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Spacing between search and filter
        const SizedBox(width: 8),
        
        // Filter Dropdown - Compact size
        Container(
          width: 120, // Fixed width for filter
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border(context),
            ),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterMethod,
              isExpanded: true,
              icon: Icon(
                Icons.filter_list,
                color: AppColors.textSecondary(context),
                size: 18,
              ),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 12,
              ),
              dropdownColor: AppColors.card(context),
              items: const [
                DropdownMenuItem(
                  value: 'all', 
                  child: Text('All Methods'),
                ),
                DropdownMenuItem(
                  value: 'cash', 
                  child: Text('Cash'),
                ),
                DropdownMenuItem(
                  value: 'online', 
                  child: Text('Online'),
                ),
                DropdownMenuItem(
                  value: 'upi', 
                  child: Text('UPI'),
                ),
                DropdownMenuItem(
                  value: 'bank_transfer', 
                  child: Text('Bank'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _filterMethod = value!;
                });
              },
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildContributionCard(ContributionModel contribution, BuildContext context, bool isAdmin) {
    return Card(
      color: AppColors.card(context),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: AppColors.border(context),
          width: 0.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.success(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.check_circle,
            color: AppColors.success(context),
            size: 20,
          ),
        ),
        title: FutureBuilder<String>(
          future: _getUserName(contribution.userId, context),
          builder: (context, snapshot) {
            final userName = snapshot.data ?? 'User';
            return Text(
              userName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                fontSize: 15,
              ),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_formatPaymentMethod(contribution.paymentMethod)} • ${DateFormat('dd/MM/yyyy').format(contribution.createdAt.toDate())}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${contribution.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary(context),
              ),
            ),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            //   decoration: BoxDecoration(
            //     color: AppColors.success(context),
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: Text(
            //     'Paid',
            //     style: TextStyle(
            //       color: Colors.white,
            //       fontSize: 9,
            //       fontWeight: FontWeight.bold,
            //     ),
            //   ),
            // ),
          ],
        ),
        onTap: isAdmin ? () {
          _showContributionActions(contribution, context);
        } : null,
      ),
    );
  }

  Widget _buildEmptyState(bool noContributions, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noContributions ? Icons.payments_outlined : Icons.search_off,
            size: 60,
            color: AppColors.textTertiary(context),
          ),
          const SizedBox(height: 8),
          Text(
            noContributions ? 'No Contributions Yet' : 'No Matching Contributions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            noContributions 
                ? 'Contributions will appear here when participants make payments'
                : 'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<ContributionModel> _filterContributions(List<ContributionModel> contributions) {
    List<ContributionModel> filtered = contributions;

    // Apply payment method filter
    if (_filterMethod != 'all') {
      filtered = filtered.where((contribution) => contribution.paymentMethod == _filterMethod).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((contribution) {
        // We'll filter by user name when we have it
        // For now, just return all
        return true;
      }).toList();
    }

    return filtered;
  }


  void _showContributionActions(ContributionModel contribution, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.25,
          maxChildSize: 0.6,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.border(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    Text(
                      'Contribution Actions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // View Details
                    _buildActionTile(
                      context: context,
                      icon: Icons.visibility_outlined,
                      title: 'View Details',
                      color: AppColors.primary(context),
                      onTap: () {
                        Navigator.pop(context);
                        _showContributionDetails(contribution, context);
                      },
                    ),

                    // Delete Contribution
                    _buildActionTile(
                      context: context,
                      icon: Icons.delete_outline,
                      title: 'Delete Contribution',
                      color: AppColors.error(context),
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(contribution, context);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Cancel Button
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.card(context),
                            foregroundColor: AppColors.textPrimary(context),
                            side: BorderSide(color: AppColors.border(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDestructive 
                          ? AppColors.error(context) 
                          : AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary(context),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContributionDetails(ContributionModel contribution, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Contribution Details',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<String>(
                future: _getUserName(contribution.userId, context),
                builder: (context, snapshot) {
                  return _buildDetailRow('User', snapshot.data ?? 'User ${contribution.userId}');
                },
              ),
              _buildDetailRow('Amount', '₹ ${contribution.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Payment Method', _formatPaymentMethod(contribution.paymentMethod)),
              _buildDetailRow('Status', 'Completed'),
              _buildDetailRow('Date', DateFormat('dd MMM yyyy, hh:mm a').format(contribution.createdAt.toDate())),
              _buildDetailRow('Contribution ID', contribution.contributionId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ContributionModel contribution, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Contribution',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this contribution of ₹ ${contribution.amount.toStringAsFixed(2)}?',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContribution(contribution, context);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error(context),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteContribution(ContributionModel contribution, BuildContext context) async {
    try {
      final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
      await contributionProvider.deleteContribution(contribution.contributionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contribution deleted successfully!'),
          backgroundColor: AppColors.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete contribution: $e'),
          backgroundColor: AppColors.error(context),
        ),
      );
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method;
    }
  }
}
this is my contribution tab so i want to add in this a fixed button plus icon for to add contributions in this program so here is my method in contribution provider to add contribution
  // Add contribution
  Future<void> addContribution(ContributionModel contribution) async {
    try {
      await _contributionService.addContribution(contribution);
      // Reload contributions after adding new one
      if (contribution.programId.isNotEmpty) {
        await loadProgramContributions(contribution.programId);
      }
      await loadUserContributions(contribution.userId, contribution.communityId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
so can you add the feature add contributions into tihs screen and you have to check the programs is is monthly payment program or not if month payment program add a input to add which month like below code
// lib/features/history/widgets/add_contribution_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/services/program_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../../features/contributions/models/contribution_model.dart';
import '../../../features/programs/models/program_model.dart';
import '../../../features/auth/models/user_model.dart';

class AddContributionModal extends StatefulWidget {
  const AddContributionModal({Key? key}) : super(key: key);

  @override
  State<AddContributionModal> createState() => _AddContributionModalState();
}

class _AddContributionModalState extends State<AddContributionModal> {
  final _contributionService = ContributionService();
  final _programService = ProgramService();
  final _userService = UserService();
  
  int _currentStep = 0;
  ProgramModel? _selectedProgram;
  UserModel? _selectedUser;
  double _amount = 0;
  String _paymentMethod = 'cash';
  final List<String> _paymentMethods = ['cash', 'online', 'bank transfer', 'other'];
  
  // ✅ ADD: Monthly contribution fields
  bool _isMonthlyProgram = false;
  String? _selectedMonth; // Format: "2025-01"
  List<String> _availableMonths = [];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final communityId = auth.user?.communityId ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 30), // Space to avoid camera notch
            
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Contribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _goToPreviousStep,
                    child: const Text('Back'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ UPDATED: Clean progress bar with step counter
            Column(
              children: [
                // Step counter row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Current step
                    Text(
                      '${_currentStep + 1}/3',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    // Total steps
                    Text(
                      '3/3',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Step-based progress bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentStep >= 0 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentStep >= 1 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentStep >= 2 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(3),
                            bottomRight: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildProgramSelectionStep(communityId),
                  _buildUserSelectionStep(),
                  _buildContributionDetailsStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramSelectionStep(String communityId) {
    return FutureBuilder<List<ProgramModel>>(
      future: _programService.getActiveProgramsByCommunity(communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final programs = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Program',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which program this contribution is for',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: programs.length,
                itemBuilder: (context, index) {
                  final program = programs[index];
                  final isMonthly = program.isMonthlyPaymentProgram;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMonthly 
                              ? Colors.green.withOpacity(0.1)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isMonthly ? Icons.calendar_month : Icons.event,
                          color: isMonthly ? Colors.green : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(program.title),
                          if (isMonthly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Monthly',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${program.programDate.day}/${program.programDate.month}/${program.programDate.year}',
                          ),
                          if (program.suggestedContribution != null && program.suggestedContribution! > 0)
                            Text(
                              'Suggested: ₹${program.suggestedContribution}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                        ],
                      ),
                      trailing: _selectedProgram?.programId == program.programId
                          ? Icon(
                              Icons.check_circle, 
                              color: isMonthly ? Colors.green : Theme.of(context).colorScheme.primary
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedProgram = program;
                          _isMonthlyProgram = program.isMonthlyPaymentProgram;
                          
                          // ✅ Generate month options if monthly program
                          if (_isMonthlyProgram) {
                            _availableMonths = _generateMonthOptions();
                            _selectedMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
                          } else {
                            _availableMonths = [];
                            _selectedMonth = null;
                          }
                        });
                        _goToNextStep();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserSelectionStep() {
    final auth = Provider.of<AppAuthProvider>(context);
    final communityId = auth.user?.communityId ?? '';

    return FutureBuilder<List<UserModel>>(
      future: _userService.getUsersByCommunity(communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final users = snapshot.data ?? [];
        final filteredUsers = users.where((user) => user.isApproved).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Member',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which member made this contribution',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Text(
                          user.displayName?.isNotEmpty == true 
                              ? user.displayName![0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(user.displayName ?? 'Unknown User'),
                      subtitle: Text(user.email),
                      trailing: _selectedUser?.uid == user.uid
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedUser = user;
                        });
                        _goToNextStep();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContributionDetailsStep() {
    // ✅ Auto-fill amount with suggested contribution
    if (_amount == 0 && _selectedProgram != null && _selectedProgram!.suggestedContribution != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _amount = _selectedProgram!.suggestedContribution!;
        });
      });
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contribution Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter contribution amount and payment method',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // ✅ ADD: Month selector for monthly programs
          if (_isMonthlyProgram && _availableMonths.isNotEmpty) ...[
            _buildMonthGridSelector(), // ✅ FIXED: Changed from _buildMonthSelector()
            const SizedBox(height: 16),
          ],

          // Amount input
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixText: _selectedProgram?.suggestedContribution != null 
                  ? 'Suggested: ₹${_selectedProgram!.suggestedContribution}'
                  : null,
            ),
            keyboardType: TextInputType.number,
            initialValue: _amount > 0 ? _amount.toString() : null,
            onChanged: (value) {
              setState(() {
                _amount = double.tryParse(value) ?? 0;
              });
            },
          ),
          const SizedBox(height: 16),

          // Payment method dropdown
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _paymentMethods.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(method[0].toUpperCase() + method.substring(1)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _paymentMethod = value!;
              });
            },
          ),
          const SizedBox(height: 20),

          // Summary
          if (_selectedProgram != null && _selectedUser != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Program: ${_selectedProgram!.title}'),
                    if (_isMonthlyProgram) 
                      Text('Type: Monthly Program Contribution'),
                    Text('Member: ${_selectedUser!.displayName}'),
                    Text('Amount: ₹$_amount'),
                    Text('Payment: ${_paymentMethod[0].toUpperCase() + _paymentMethod.substring(1)}'),
                    if (_isMonthlyProgram && _selectedMonth != null)
                      Text('Month: ${_getMonthDisplayName(_selectedMonth!)}'),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _amount > 0 ? _submitContribution : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isMonthlyProgram ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                _isMonthlyProgram ? 'Add Monthly Contribution' : 'Add Contribution',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

Widget _buildMonthGridSelector() {
  // Find index of current month
  final currentMonthIndex = _availableMonths.indexWhere(
    (month) => month == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}",
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Select Month *',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      
      SizedBox(
        height: 80,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate position to scroll to
            final double itemWidth = 70; // Width of each month card
            final double spacing = 12; // Right padding
            final double centerOffset = (constraints.maxWidth / 2) - (itemWidth / 2);
            
            return Scrollable(
              axisDirection: AxisDirection.right,
              controller: ScrollController(),
              viewportBuilder: (context, offset) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Auto-scroll to current month after build
                  if (currentMonthIndex != -1) {
                    final double targetOffset = 
                        (currentMonthIndex * (itemWidth + spacing)) - centerOffset;
                    
                    // Use a scroll controller to programmatically scroll
                    Scrollable.ensureVisible(
                      context,
                      alignment: 0.5, // Center alignment
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                });
                
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  controller: ScrollController(
                    initialScrollOffset: currentMonthIndex != -1 
                        ? (currentMonthIndex * (itemWidth + spacing)) - centerOffset
                        : 0,
                  ),
                  itemCount: _availableMonths.length,
                  itemBuilder: (context, index) {
                    final month = _availableMonths[index];
                    final isSelected = _selectedMonth == month;
                    final isCurrentMonth = month == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
                    
                    return Padding(
                      padding: EdgeInsets.only(
                        right: 12,
                        left: index == 0 ? 12 : 0, // Add left padding for first item
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMonth = month),
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.blue 
                                : (isCurrentMonth ? Colors.blue[50] : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.blue : (Colors.grey[300] ?? Colors.grey),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected 
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getMonthAbbreviation(month),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                _getYear(month),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                ),
                              ),
                              if (isCurrentMonth)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.blue[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Current',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isSelected ? Colors.blue : Colors.blue[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      
      // Selected month info
      if (_selectedMonth != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Selected: ${_getMonthDisplayName(_selectedMonth!)}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      
      // Scroll hint
      if (_availableMonths.length > 5)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_left, size: 16, color: Colors.grey[500]),
              Text(
                ' Scroll for more months ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Icon(Icons.arrow_right, size: 16, color: Colors.grey[500]),
            ],
          ),
        ),
    ],
  );
}

String _getMonthAbbreviation(String monthId) {
  final parts = monthId.split('-');
  final month = int.parse(parts[1]);
  return DateFormat('MMM').format(DateTime(0, month));
}

String _getYear(String monthId) {
  final parts = monthId.split('-');
  return parts[0];
}

List<String> _generateMonthOptions() {
  final List<String> months = [];
  final now = DateTime.now();
  
  // Generate 6 months before current, current month, and 6 months after
  for (int i = -6; i <= 6; i++) {
    final date = DateTime(now.year, now.month + i, 1);
    final monthStr = "${date.year}-${date.month.toString().padLeft(2, '0')}";
    months.add(monthStr);
  }
  
  return months;
}

  // ✅ ADD: Get month display name
  String _getMonthDisplayName(String monthId) {
    final parts = monthId.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);
    
    // Show "Jan 2024" format
    final monthName = DateFormat('MMM').format(date);
    
    // Add "(Current)" for current month
    final currentMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
    final suffix = monthId == currentMonth ? " (Current)" : "";
    
    return "$monthName $year$suffix";
  }

  void _goToNextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _submitContribution() async {
    if (_selectedProgram == null || _selectedUser == null || _amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    
    // ✅ ADD: Validate month selection for monthly programs
    if (_isMonthlyProgram && (_selectedMonth == null || _selectedMonth!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select month for monthly contribution')),
      );
      return;
    }

    try {
      final contribution = ContributionModel(
        contributionId: '', // Will be set by Firestore
        programId: _selectedProgram!.programId,
        userId: _selectedUser!.uid,
        communityId: _selectedProgram!.communityId,
        amount: _amount,
        paymentMethod: _paymentMethod,
        // ✅ ADD: Monthly fields
        isMonthlyContribution: _isMonthlyProgram,
        monthId: _isMonthlyProgram ? _selectedMonth : null,
      );

      await _contributionService.addContribution(contribution);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution added successfully!')),
      );

      Navigator.pop(context); // Close modal
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding contribution: $e')),
      );
    }
  }
}