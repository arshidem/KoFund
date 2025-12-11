import 'package:flutter/foundation.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import '../../../../core/services/user_service.dart';

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
    // Fetch all users belonging to this community
    final allUsers = await _userService.getUsersByCommunity(communityId);

    print('DEBUG: Total users fetched: ${allUsers.length}');
    
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
    
    print('DEBUG: Approved count: ${_approvedMembers.length}');
    print('DEBUG: Pending count: ${_pendingMembers.length}');
    
    _setMessage('Community members loaded successfully');
  } catch (e) {
    print('ERROR loading community members: $e');
    _setMessage('Error loading community members: $e');
  } finally {
    _setLoading(false);
  }
}

// --------------------------------------------------------------------------
// 🔄 UNAPPROVE USER (Remove from members) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> unapproveUser(String uid) async {
  _setLoading(true);
  try {
    // 🔹 Update in Firestore FIRST
    await _userService.unapproveUser(uid);
    
    // 🔹 Find user in approved list
    final userIndex = _approvedMembers.indexWhere((user) => user.uid == uid);
    if (userIndex != -1) {
      // 🔹 Get a FRESH copy of the user
      final user = _approvedMembers[userIndex].copyWith(isApproved: false);
      
      // 🔹 Create NEW lists (don't modify in-place)
      final newApproved = List<UserModel>.from(_approvedMembers);
      final newPending = List<UserModel>.from(_pendingMembers);
      
      // 🔹 Remove from approved
      newApproved.removeAt(userIndex);
      
      // 🔹 Add to pending
      newPending.add(user);
      
      // 🔹 Assign new lists
      _approvedMembers = newApproved;
      _pendingMembers = newPending;
      
      print('DEBUG: After unapprove - Approved: ${_approvedMembers.length}, Pending: ${_pendingMembers.length}');
    }
    
    _setMessage('User removed from approved members');
  } catch (e) {
    print('ERROR unapproving user: $e');
    _setMessage('Error unapproving user: $e');
    
    // 🔹 Reload data to ensure consistency
    // You might want to get communityId from somewhere
    // await loadCommunityMembers(communityId);
  } finally {
    _setLoading(false);
  }
}

// --------------------------------------------------------------------------
// 🟢 APPROVE USER (Make them a member) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> approveUser(String uid, String communityId) async {
  _setLoading(true);
  try {
    await _userService.approveUser(uid);

    // 🔹 Find user in pending list
    final pendingIndex = _pendingMembers.indexWhere((u) => u.uid == uid);
    if (pendingIndex != -1) {
      // 🔹 Get a FRESH copy of the user
      final user = _pendingMembers[pendingIndex].copyWith(isApproved: true);
      
      // 🔹 Create NEW lists (don't modify in-place)
      final newPending = List<UserModel>.from(_pendingMembers);
      final newApproved = List<UserModel>.from(_approvedMembers);
      
      // 🔹 Remove from pending
      newPending.removeAt(pendingIndex);
      
      // 🔹 Add to approved
      newApproved.add(user);
      
      // 🔹 Assign new lists
      _pendingMembers = newPending;
      _approvedMembers = newApproved;
      
      print('DEBUG: After approve - Approved: ${_approvedMembers.length}, Pending: ${_pendingMembers.length}');
    }

    _setMessage('User approved successfully');
  } catch (e) {
    print('ERROR approving user: $e');
    _setMessage('Error approving user: $e');
  } finally {
    _setLoading(false);
  }
}

// --------------------------------------------------------------------------
// 🔴 REJECT USER (Remove from pending) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> rejectUser(String uid) async {
  _setLoading(true);
  try {
    await _userService.rejectUser(uid);
    
    // 🔹 Create NEW pending list (don't modify in-place)
    final newPending = List<UserModel>.from(_pendingMembers);
    newPending.removeWhere((u) => u.uid == uid);
    
    // 🔹 Assign new list
    _pendingMembers = newPending;
    
    print('DEBUG: After reject - Pending: ${_pendingMembers.length}');
    
    _setMessage('User rejected successfully');
  } catch (e) {
    print('ERROR rejecting user: $e');
    _setMessage('Error rejecting user: $e');
  } finally {
    _setLoading(false);
  }
}

// --------------------------------------------------------------------------
// 👑 UPDATE USER ROLE (Admin/Non-Admin) - FIXED VERSION
// --------------------------------------------------------------------------
Future<void> updateUserRole(String uid, bool isAdmin) async {
  _setLoading(true);
  try {
    await _userService.updateUserRole(uid, isAdmin);
    
    // 🔹 Create NEW lists
    final newApproved = List<UserModel>.from(_approvedMembers);
    final newPending = List<UserModel>.from(_pendingMembers);
    
    // 🔹 Helper function to update user in a list
    void updateInList(List<UserModel> list, String uid, bool isAdminValue) {
      final index = list.indexWhere((user) => user.uid == uid);
      if (index != -1) {
        list[index] = list[index].copyWith(isAdmin: isAdminValue);
      }
    }
    
    updateInList(newApproved, uid, isAdmin);
    updateInList(newPending, uid, isAdmin);
    
    // ✅ If user is no longer admin, remove from approved members
    if (!isAdmin) {
      newApproved.removeWhere((user) => user.uid == uid);
    }
    
    // 🔹 Assign new lists
    _approvedMembers = newApproved;
    _pendingMembers = newPending;
    
    _setMessage('User role updated successfully');
  } catch (e) {
    _setMessage('Error updating user role: $e');
  } finally {
    _setLoading(false);
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
    _approvedMembers.clear();
    _pendingMembers.clear();
    _message = null;
    _isLoading = false;
    notifyListeners();
  }
}