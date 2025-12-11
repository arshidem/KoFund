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