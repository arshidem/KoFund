import 'package:flutter/material.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConvertUserDialog extends StatefulWidget {
  final UserModel virtualUser;
  final String? currentUserId; // Exclude the current admin from the list

  const ConvertUserDialog({
    Key? key,
    required this.virtualUser,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<ConvertUserDialog> createState() => _ConvertUserDialogState();
}

class _ConvertUserDialogState extends State<ConvertUserDialog> {
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  List<UserModel> _realUsers = [];
  List<UserModel> _filteredUsers = [];
  UserModel? _selectedUser;
  bool _isLoading = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadRealUsers();
  }

  Future<void> _loadRealUsers() async {
    setState(() => _isLoading = true);
    try {
      final communityId = widget.virtualUser.communityId;
      if (communityId == null || communityId.isEmpty) {
        debugPrint('❌ Virtual user has no communityId — cannot load real users');
        setState(() => _isLoading = false);
        return;
      }
      _realUsers = await _userService.getUsersByCommunity(
        communityId,
        filterTeventType: 'real',
      );
      // Exclude: the virtual user itself, the current admin, and already-merged users
      _realUsers.removeWhere((u) =>
          u.uid == widget.virtualUser.uid ||
          u.uid == widget.currentUserId ||
          u.isVirtualUser == true);
      _filteredUsers = List.from(_realUsers);
      debugPrint('✅ Loaded ${_realUsers.length} real users for community $communityId (excluded current admin)');
    } catch (e) {
      debugPrint('❌ Failed to load real users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      _search = query;
      _filteredUsers = _realUsers
          .where((u) => ((u.displayName ?? u.email).toLowerCase()).contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _convert() async {
    if (_selectedUser == null) return;
    HapticHelper.light();
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminName = currentUser?.displayName ?? 'Admin';

      // Send a conversion request notification to the real user
      await _notificationService.sendUserNotification(
        userId: _selectedUser!.uid,
        title: 'Account Merge Request',
        body: 'Admin "$adminName" wants to merge the virtual member "${widget.virtualUser.displayName}" into your account. All data from the virtual user will be transferred to you.',
        type: NotificationType.conversionRequest,
        communityId: widget.virtualUser.communityId,
        senderName: adminName,
        data: {
          'virtualUserId': widget.virtualUser.uid,
          'virtualUserName': widget.virtualUser.displayName ?? 'Unknown',
          'virtualUserEmail': widget.virtualUser.email,
          'virtualUserPhone': widget.virtualUser.phoneNumber ?? '',
          'realUserId': _selectedUser!.uid,
          'realUserName': _selectedUser!.displayName ?? _selectedUser!.email,
          'communityId': widget.virtualUser.communityId ?? '',
          'adminId': currentUser?.uid ?? '',
          'adminName': adminName,
        },
      );

      HapticHelper.success();
      SnackbarHelper.showSuccess(context, 'Conversion request sent to ${_selectedUser!.displayName ?? _selectedUser!.email}');
      Navigator.of(context).pop(true);
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to send request: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: double.infinity,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Convert Virtual User to Real User',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'This action cannot be undone. All data from the virtual user will be transferred to the selected real user.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search real users',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _filter,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final selected = _selectedUser?.uid == user.uid;
                        return ListTile(
                          title: Text(user.displayName ?? user.email),
                          subtitle: Text(user.email),
                          trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
                          selected: selected,
                          onTap: () => setState(() => _selectedUser = user),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedUser == null || _isLoading ? null : _convert,
                    child: const Text('Send Request'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
