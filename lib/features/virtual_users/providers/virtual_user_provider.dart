import 'package:flutter/material.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/services/virtual_user_service.dart';

class VirtualUserProvider extends ChangeNotifier {
  final VirtualUserService _service;
  
  // State for bulk creation
  bool _isLoading = false;
  final List<String> _errorMessages = [];
  int _successfulCreations = 0;
  List<UserModel> _virtualUsers = [];
  final List<Map<String, dynamic>> _failedUsers = [];
  
  // State for individual operations
  bool _isDeleting = false;
  String? _deleteError;
  
  // Add these for edit operations
  bool _isEditing = false;
  String? _editError; // Add this line
  
  bool get isLoading => _isLoading;
  bool get isDeleting => _isDeleting;
  bool get isEditing => _isEditing; // Add this getter
  List<String> get errorMessages => _errorMessages;
  String? get deleteError => _deleteError;
  String? get editError => _editError; // Add this getter
  int get successfulCreations => _successfulCreations;
  List<UserModel> get virtualUsers => _virtualUsers;
  List<Map<String, dynamic>> get failedUsers => _failedUsers;
  
  VirtualUserProvider(this._service);
  // ==================== BULK CREATION METHODS ====================
/// Create multiple virtual users at once
Future<void> createMultipleUsers(
  String communityId,
  String adminUid,
  String adminName, // Add this parnameter
  List<Map<String, dynamic>> users,
) async {
  _isLoading = true;
  _errorMessages.clear();
  _failedUsers.clear();
  _successfulCreations = 0;
  notifyListeners();

  try {
    // Prepare data in the format your service expects
    final usersData = <Map<String, dynamic>>[];
    
    for (int i = 0; i < users.length; i++) {
      final user = users[i];
      final name = user['name'] as String?;
      final phone = user['phone'] as String? ?? '';
      final email = user['email'] as String? ?? '';

      // Validation
      if (name == null || name.trim().isEmpty) {
        final err = _formatError(i, 'Name is required', 'Please enter a name for the member.');
        _errorMessages.add(err);
        _failedUsers.add({'name': '', 'phone': phone, 'email': email, 'error': err});
        continue;
      }
      
      if (name.length < 2) {
        final err = _formatError(i, 'Name must be at least 2 characters', 'A longer name helps identify the member.');
        _errorMessages.add(err);
        _failedUsers.add({'name': name, 'phone': phone, 'email': email, 'error': err});
        continue;
      }
      
      if (phone.isNotEmpty && !_isValidPhoneNumber(phone)) {
        final err = _formatError(i, 'Invalid phone number format', 'Enter a valid phone, e.g., +1234567890.');
        _errorMessages.add(err);
        _failedUsers.add({'name': name, 'phone': phone, 'email': email, 'error': err});
        continue;
      }
      
      if (email.isNotEmpty && !_isValidEmail(email)) {
        final err = _formatError(i, 'Invalid email format', 'Enter a correct email like name@example.com.');
        _errorMessages.add(err);
        _failedUsers.add({'name': name, 'phone': phone, 'email': email, 'error': err});
        continue;
      }

      // Check duplicates within the batch data itself
      final isDuplicateInList = usersData.any((u) => 
        (u['name'] as String).toLowerCase() == name.toLowerCase() ||
        (u['phone'] != null && phone.isNotEmpty && u['phone'] == phone) ||
        (u['email'] != null && email.isNotEmpty && (u['email'] as String).toLowerCase() == email.toLowerCase())
      );
      if (isDuplicateInList) {
        final err = _formatError(i, 'Duplicate entry in list', 'This member details (name, email, or phone) are already entered in this form. Please use unique details.');
        _errorMessages.add(err);
        _failedUsers.add({'name': name, 'phone': phone, 'email': email, 'error': err});
        continue;
      }

      // Check if user already exists in current local cache list
      String? localDuplicateError;
      for (final cacheUser in _virtualUsers) {
        if (cacheUser.displayName?.toLowerCase() == name.toLowerCase()) {
          localDuplicateError = 'Member with name "$name" already exists in this community. Please use a different name or add initials (e.g. "$name A").';
          break;
        }
        if (phone.isNotEmpty && cacheUser.phoneNumber == phone) {
          localDuplicateError = 'Member "$name" has phone "$phone" which already exists in this community. Please use a different phone number.';
          break;
        }
        if (email.isNotEmpty && cacheUser.email.toLowerCase() == email.toLowerCase()) {
          localDuplicateError = 'Member "$name" has email "$email" which already exists in this community. Please use a different email.';
          break;
        }
      }

      if (localDuplicateError != null) {
        final err = _formatError(i, 'Member already exists', localDuplicateError);
        _errorMessages.add(err);
        _failedUsers.add({'name': name, 'phone': phone, 'email': email, 'error': err});
        continue;
      }

      usersData.add({
        'name': name.trim(),
        'phone': phone.isNotEmpty ? phone : null,
        'email': email.isNotEmpty ? email : null,
      });
    }

    if (usersData.isNotEmpty) {
      // Call the service method - returns a VirtualUserCreationResult
      final result = await _service.createMultipleVirtualUsers(
        communityId: communityId,
        adminUid: adminUid,
        adminName: adminName, // Pass admin name here
        usersData: usersData,
      );
      
      _successfulCreations = result.createdUsers.length;
      _virtualUsers.addAll(result.createdUsers);
      
      for (final failed in result.failedUsers) {
        _failedUsers.add(failed);
        _errorMessages.add(failed['error'] as String? ?? 'Unknown error');
      }
    }
  } catch (e) {
    _errorMessages.add('Failed to create users: $e');
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// Alternative: Create single virtual user
Future<bool> createVirtualUser({
  required String displayName,
  required String communityId,
  required String adminUid,
  required String adminName, // Add this parnameter
  String? phoneNumber,
  String? email,
}) async {
  _isLoading = true;
  _errorMessages.clear();
  notifyListeners();

  try {
    // Validate inputs
    if (displayName.trim().isEmpty) {
      _errorMessages.add('Display name is required');
      _isLoading = false;
      notifyListeners();
      return false;
    }
    
    if (displayName.length < 2) {
      _errorMessages.add('Display name must be at least 2 characters');
      _isLoading = false;
      notifyListeners();
      return false;
    }
    
    if (phoneNumber != null && phoneNumber.isNotEmpty && !_isValidPhoneNumber(phoneNumber)) {
      _errorMessages.add('Invalid phone number format');
      _isLoading = false;
      notifyListeners();
      return false;
    }
    
    if (email != null && email.isNotEmpty && !_isValidEmail(email)) {
      _errorMessages.add('Invalid email format');
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Call the service method - pass adminName
    final user = await _service.createVirtualUser(
      communityId: communityId,
      displayName: displayName.trim(),
      adminUid: adminUid,
      adminName: adminName, // Pass admin name here
      phoneNumber: phoneNumber?.trim(),
      email: email?.trim(),
    );
    
    _successfulCreations++;
    _virtualUsers.add(user);
    _isLoading = false;
    notifyListeners();
    return true;
    
  } catch (e) {
    _errorMessages.add('Failed to create user: $e');
    _isLoading = false;
    notifyListeners();
    return false;
  }
}
  

   Future<bool> editVirtualUser({
    required String userId,
    required String displayName,
    String? phoneNumber,
    String? email,
  }) async {
    _isEditing = true;
    _editError = null;
    notifyListeners();

    try {
      // Validation
      if (displayName.trim().isEmpty) {
        _editError = 'Display name is required';
        _isEditing = false;
        notifyListeners();
        return false;
      }
      
      if (displayName.length < 2) {
        _editError = 'Display name must be at least 2 characters';
        _isEditing = false;
        notifyListeners();
        return false;
      }
      
      if (phoneNumber != null && phoneNumber.isNotEmpty && !_isValidPhoneNumber(phoneNumber)) {
        _editError = 'Invalid phone number format';
        _isEditing = false;
        notifyListeners();
        return false;
      }
      
      if (email != null && email.isNotEmpty && !_isValidEmail(email)) {
        _editError = 'Invalid email format';
        _isEditing = false;
        notifyListeners();
        return false;
      }

      // Call service method
      await _service.updateVirtualUser(
        userId: userId,
        displayName: displayName.trim(),
        phoneNumber: phoneNumber?.trim(),
        email: email?.trim(),
      );
      
      // Update local list
      final index = _virtualUsers.indexWhere((user) => user.uid == userId);
      if (index != -1) {
        _virtualUsers[index] = _virtualUsers[index].copyWith(
          displayName: displayName.trim(),
          phoneNumber: phoneNumber?.trim(),
          email: email?.trim(),
        );
      }
      
      _isEditing = false;
      notifyListeners();
      return true;
      
    } catch (e) {
      _editError = 'Failed to edit virtual user: $e';
      _isEditing = false;
      notifyListeners();
      return false;
    }
  }

  
  // ==================== DELETE METHODS ====================
  
  /// Delete a virtual user
  Future<bool> deleteVirtualUser(String userId) async {
    _isDeleting = true;
    _deleteError = null;
    notifyListeners();

    try {
      await _service.deleteVirtualUser(userId);
      
      // Remove from local list
      _virtualUsers.removeWhere((user) => user.uid == userId);
      
      _isDeleting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _deleteError = 'Failed to delete virtual user: $e';
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Bulk delete virtual users
  Future<Map<String, dynamic>> bulkDeleteVirtualUsers(List<String> userIds) async {
    _isLoading = true;
    _errorMessages.clear();
    notifyListeners();

    int successCount = 0;
    int failedCount = 0;
    final failedUsers = <String>[];

    try {
      // Use the service's batch delete method
      await _service.deleteMultipleVirtualUsers(userIds);
      
      successCount = userIds.length;
      
      // Remove from local list
      _virtualUsers.removeWhere((user) => userIds.contains(user.uid));
      
    } catch (e) {
      _errorMessages.add('Failed to delete users: $e');
      failedCount = userIds.length;
      failedUsers.addAll(userIds);
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return {
      'successCount': successCount,
      'failedCount': failedCount,
      'failedUsers': failedUsers,
    };
  }
  
  // ==================== FETCH METHODS ====================
  
  /// Load virtual users for a community
  Future<void> loadVirtualUsers(String communityId, {bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessages.clear();
    notifyListeners();

    try {
      _virtualUsers = await _service.getVirtualUsers(communityId, forceRefresh: forceRefresh);
    } catch (e) {
      _errorMessages.add('Failed to load virtual users: $e');
      _virtualUsers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get single virtual user by ID
  Future<UserModel?> getVirtualUser(String userId) async {
    try {
      return await _service.getVirtualUserById(userId);
    } catch (e) {
      _errorMessages.add('Failed to get user: $e');
      return null;
    }
  }
  
  /// Search virtual users
  Future<List<UserModel>> searchVirtualUsers({
    required String communityId,
    required String query,
  }) async {
    try {
      return await _service.searchVirtualUsers(
        communityId: communityId,
        query: query,
      );
    } catch (e) {
      _errorMessages.add('Failed to search users: $e');
      return [];
    }
  }
  
  /// Check for duplicate user name
  Future<bool> checkDuplicateUser({
    required String communityId,
    required String displayName,
  }) async {
    try {
      return await _service.checkDuplicateUser(
        communityId: communityId,
        displayName: displayName,
      );
    } catch (e) {
      _errorMessages.add('Failed to check duplicate: $e');
      return false;
    }
  }
  
  /// Get virtual user count
  Future<int> getVirtualUserCount(String communityId, {bool forceRefresh = false}) async {
    try {
      return await _service.getVirtualUserCount(communityId, forceRefresh: forceRefresh);
    } catch (e) {
      _errorMessages.add('Failed to get count: $e');
      return 0;
    }
  }
  
  // ==================== STREAM METHODS ====================
  
  /// Stream for virtual users
  Stream<List<UserModel>> getVirtualUsersStream(String communityId) {
    return _service.getVirtualUsersStream(communityId);
  }
  
  /// Stream for virtual user count
  Stream<int> getVirtualUserCountStream(String communityId) {
    return _service.getVirtualUserCountStream(communityId);
  }
  
  

  // ==================== UTILITY METHODS ====================
  
  /// Reset creation state
  void resetCreationState() {
    _errorMessages.clear();
    _successfulCreations = 0;
    notifyListeners();
  }
  
  /// Clear errors
  void clearErrors() {
    _errorMessages.clear();
    _deleteError = null;
    notifyListeners();
  }
  
  /// Clear all data
  void clearData() {
    _virtualUsers.clear();
    _errorMessages.clear();
    _successfulCreations = 0;
    _isLoading = false;
    _isDeleting = false;
    _deleteError = null;
    notifyListeners();
  }
  
  /// Clear service cache
  void clearServiceCache() {
    _service.clearAllCache();
  }
  
  // ==================== PRIVATE HELPERS ====================
  
  bool _isValidPhoneNumber(String phone) {
    return _service.isValidPhoneNumber(phone);
  }

  bool _isValidEmail(String email) {
  return _service.isValidEmail(email);
}

// Formats error messages with user-friendly suggestions
String _formatError(int userIndex, String title, String suggestion) {
  return 'User \\${userIndex + 1}: \\$title – \\$suggestion';
}
    void clearEditError() {
    _editError = null;
    notifyListeners();
  }
}





