import 'package:flutter/material.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

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
  bool _isLoadingUsers = false;
  bool _isSendingRequest = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadRealUsers();
  }

  Future<void> _loadRealUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final communityId = widget.virtualUser.communityId;
      if (communityId == null || communityId.isEmpty) {
        debugPrint('❌ Virtual user has no communityId — cannot load real users');
        setState(() => _isLoadingUsers = false);
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
      setState(() => _isLoadingUsers = false);
    }
  }

  void _filter(String query) {
    if (_isSendingRequest) return;
    setState(() {
      _search = query;
      _filteredUsers = _realUsers
          .where((u) => ((u.displayName ?? u.email).toLowerCase()).contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _convert() async {
    if (_selectedUser == null) return;
    final selectedUser = _selectedUser!;
    HapticHelper.light();
    setState(() => _isSendingRequest = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminName = currentUser?.displayName ?? 'Admin';

      // Send a conversion request notification to the real user
      await _notificationService.sendUserNotification(
        userId: selectedUser.uid,
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
          'realUserId': selectedUser.uid,
          'realUserName': selectedUser.displayName ?? selectedUser.email,
          'communityId': widget.virtualUser.communityId ?? '',
          'adminId': currentUser?.uid ?? '',
          'adminName': adminName,
        },
      );

      HapticHelper.success();
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, 'Conversion request sent to ${selectedUser.displayName ?? selectedUser.email}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Failed to send request: $e');
    } finally {
      if (mounted) {
        setState(() => _isSendingRequest = false);
      }
    }
  }

  Widget _buildUsersSkeleton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100;

    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            title: Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 180,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        );
      },
    );
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
                enabled: !_isSendingRequest,
                decoration: const InputDecoration(
                  hintText: 'Search real users',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _filter,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoadingUsers
                  ? _buildUsersSkeleton()
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
                          onTap: _isSendingRequest ? null : () => setState(() => _selectedUser = user),
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
                    onPressed: _isSendingRequest ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedUser == null || _isSendingRequest ? null : _convert,
                    child: _isSendingRequest
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Send Request'),
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
