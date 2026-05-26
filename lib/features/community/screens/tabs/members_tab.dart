// lib/features/community/screens/tabs/members_tab.dart
import 'package:flutter/material.dart';
import 'package:kofund/features/members/screens/all_members_screen.dart';

class MembersTab extends StatefulWidget {
  const MembersTab({super.key});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return const AllMembersScreen();
  }
}
