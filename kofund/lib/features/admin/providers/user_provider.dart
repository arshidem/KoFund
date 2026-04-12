import 'package:flutter/foundation.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import '../../../../core/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService;
  
  UserProvider(this._userService);

  List<UserModel> _approvedMembers = [];
  List<UserModel> _pendingMembers = [];
  bool _isLoading = false;
  String? _message;

  // Getters with defensive copying
  List<UserModel> get approvedMembers => List<UserModel>.from(_approvedMembers);
  List<UserModel> get pendingMembers => List<UserModel>.from(_pendingMembers);
  bool get isLoading => _isLoading;
  String? get message => _message;

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _setMessage(String? msg) {
    if (_message != msg) {
      _message = msg;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // 🧩 LOAD COMMUNITY MEMBERS 
  // --------------------------------------------------------------------------
Future<void> loadCommunityMembers(String communityId) async {
  _setLoading(true);
  try {
    // Fetch all users belonging to this community (now including unapproved ones for admin)
    final allUsers = await _userService.getUsersByCommunity(
      communityId, 
      includeUnapproved: true,
    );

    debugPrint('DEBUG: Total users fetched: ${allUsers.length}');
    
    // ✅ Create NEW lists to avoid reference issues
    final List<UserModel> newApproved = [];
    final List<UserModel> newPending = [];
    
    for (var user in allUsers) {
      // ✅ Create a fresh copy of each user
      final userCopy = user.copyWith();
      
      if (user.isApproved == true) {
        newApproved.add(userCopy);
      } else {
        newPending.add(userCopy);
      }
    }
    
    // ✅ Assign new lists (don't modify in-place)
    _approvedMembers = newApproved;
    _pendingMembers = newPending;
    
    debugPrint('DEBUG: Approved count: ${_approvedMembers.length}');
    debugPrint('DEBUG: Pending count: ${_pendingMembers.length}');
    
    _setMessage('Community members loaded successfully');
  } catch (e) {
    debugPrint('ERROR loading community members: $e');
    _setMessage('Error loading community members: $e');
  } finally {
    _setLoading(false);
  }
}

// --------------------------------------------------------------------------
// 🔄 UNAPPROVE USER (Remove from members) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> unapproveUser(String uid) async {
  // 1. Optimistic Update
  final userIndex = _approvedMembers.indexWhere((user) => user.uid == uid);
  UserModel? originalUser;
  if (userIndex != -1) {
    originalUser = _approvedMembers[userIndex];
    final user = originalUser.copyWith(isApproved: false);
    
    _approvedMembers.removeAt(userIndex);
    _pendingMembers.add(user);
    notifyListeners();
  }

  try {
    await _userService.unapproveUser(uid);
    _setMessage('User removed from approved members');
  } catch (e) {
    // 2. Revert on failure
    if (userIndex != -1 && originalUser != null) {
      _pendingMembers.removeWhere((u) => u.uid == uid);
      _approvedMembers.insert(userIndex, originalUser);
      notifyListeners();
    }
    debugPrint('ERROR unapproving user: $e');
    _setMessage('Error unapproving user: $e');
  }
}

// 🟢 APPROVE USER (Make them a member) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> approveUser(String uid, String communityId, {String? adminName}) async {
  // 1. Optimistic Update
  final pendingIndex = _pendingMembers.indexWhere((u) => u.uid == uid);
  UserModel? originalUser;
  if (pendingIndex != -1) {
    originalUser = _pendingMembers[pendingIndex];
    final user = originalUser.copyWith(isApproved: true);
    
    _pendingMembers.removeAt(pendingIndex);
    _approvedMembers.add(user);
    notifyListeners();
  }

  try {
    await _userService.approveUser(uid, adminName: adminName);
    _setMessage('User approved successfully');
  } catch (e) {
    // 2. Revert on failure
    if (pendingIndex != -1 && originalUser != null) {
      _approvedMembers.removeWhere((u) => u.uid == uid);
      _pendingMembers.insert(pendingIndex, originalUser);
      notifyListeners();
    }
    debugPrint('ERROR approving user: $e');
    _setMessage('Error approving user: $e');
  }
}

// --------------------------------------------------------------------------
// 🔴 REJECT USER (Remove from pending) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> rejectUser(String uid) async {
  // 1. Optimistic Update
  final pendingIndex = _pendingMembers.indexWhere((u) => u.uid == uid);
  UserModel? removedUser;
  if (pendingIndex != -1) {
    removedUser = _pendingMembers.removeAt(pendingIndex);
    notifyListeners();
  }

  try {
    // 🔹 1. Get user's communityId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final communityId = userDoc.data()?['communityId'] as String?;

    if (communityId == null || communityId.isEmpty) {
      // Revert if no community ID - arguably we could skip revert if doc not found
      if (removedUser != null) {
        _pendingMembers.insert(pendingIndex, removedUser);
        notifyListeners();
      }
      _setMessage('User is not in any community');
      return;
    }

    // 🔹 2. Call UserService with POSITIONAL parameters
    await _userService.rejectUser(uid, communityId);
    _setMessage('User rejected successfully');
  } catch (e) {
    // 2. Revert on failure
    if (pendingIndex != -1 && removedUser != null) {
      _pendingMembers.insert(pendingIndex, removedUser);
      notifyListeners();
    }
    debugPrint('❌ ERROR rejecting user: $e');
    _setMessage('Error rejecting user: $e');
  }
}


// --------------------------------------------------------------------------
// 👑 UPDATE USER ROLE (Admin/Non-Admin) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> updateUserRole(String uid, bool isAdmin) async {
  // 1. Optimistic Update
  final Map<String, int> listIndices = {
    'approved': _approvedMembers.indexWhere((u) => u.uid == uid),
    'pending': _pendingMembers.indexWhere((u) => u.uid == uid),
  };
  
  final Map<String, UserModel> originals = {};
  if (listIndices['approved'] != -1) {
    originals['approved'] = _approvedMembers[listIndices['approved']!];
    _approvedMembers[listIndices['approved']!] = originals['approved']!.copyWith(isAdmin: isAdmin);
  }
  if (listIndices['pending'] != -1) {
    originals['pending'] = _pendingMembers[listIndices['pending']!];
    _pendingMembers[listIndices['pending']!] = originals['pending']!.copyWith(isAdmin: isAdmin);
  }

  // Special logic: if user is no longer admin, remove from approved? 
  // Wait, the original code had this logic. Let's keep it but optimistically.
  UserModel? removedFromApproved;
  if (!isAdmin && listIndices['approved'] != -1) {
    removedFromApproved = _approvedMembers.removeAt(listIndices['approved']!);
  }

  notifyListeners();

  try {
    await _userService.updateUserRole(uid, isAdmin);
    _setMessage('User role updated successfully');
  } catch (e) {
    // 2. Revert on failure
    if (removedFromApproved != null) {
      _approvedMembers.insert(listIndices['approved']!, removedFromApproved);
    }
    if (originals['approved'] != null) {
      _approvedMembers[listIndices['approved']!] = originals['approved']!;
    }
    if (originals['pending'] != null) {
      _pendingMembers[listIndices['pending']!] = originals['pending']!;
    }
    notifyListeners();
    _setMessage('Error updating user role: $e');
  }
}

// --------------------------------------------------------------------------
// ⚫ REMOVE USER COMPLETELY (Admin Only) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> removeUser(String uid) async {
  _setLoading(true);
  try {
    await _userService.deleteUser(uid);
    
    // 🔹 Create NEW lists
    final newApproved = List<UserModel>.from(_approvedMembers);
    final newPending = List<UserModel>.from(_pendingMembers);
    
    newApproved.removeWhere((u) => u.uid == uid);
    newPending.removeWhere((u) => u.uid == uid);
    
    // 🔹 Assign new lists
    _approvedMembers = newApproved;
    _pendingMembers = newPending;
    
    _setMessage('User removed successfully');
  } catch (e) {
    _setMessage('Error removing user: $e');
  } finally {
    _setLoading(false);
  }
}


  // --------------------------------------------------------------------------
  // 🟡 USER PROFILE UPDATE (NAME / PHONE)
// --------------------------------------------------------------------------

  // --------------------------------------------------------------------------
  // 🔧 HELPER METHODS
  // --------------------------------------------------------------------------
  
  // Helper to update user in any list
  void _updateUserInList(List<UserModel> list, String uid, UserModel Function(UserModel) update) {
    final index = list.indexWhere((user) => user.uid == uid);
    if (index != -1) {
      list[index] = update(list[index]);
    }
  }

  // Check if user is an active member
  bool isUserActiveMember(String uid) {
    return _approvedMembers.any((user) => 
      user.uid == uid && user.isApproved == true && user.isAdmin == true
    );
  }

  // Get user membership status
  String getUserMembershipStatus(String uid) {
    if (_approvedMembers.any((user) => user.uid == uid && user.isAdmin == true)) {
      return 'Active Member';
    } else if (_pendingMembers.any((user) => user.uid == uid)) {
      return 'Pending Approval';
    } else if (_approvedMembers.any((user) => user.uid == uid && user.isAdmin == false)) {
      return 'Former Member (Not Admin)';
    } else {
      return 'Not a Member';
    }
  }

  void clearMessages() {
    _message = null;
    notifyListeners();
  }

void clearData() {
  _approvedMembers.clear(); // Changed from _members.clear()
  _pendingMembers.clear();
  _message = null;
  _isLoading = false;
  notifyListeners();
}

}

