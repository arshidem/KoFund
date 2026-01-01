import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/models/user_model.dart';
import 'package:kofund/core/services/virtual_user_service.dart';

class VirtualUserProvider extends ChangeNotifier {
  final VirtualUserService _service;
  
  // State for bulk creation
  bool _isLoading = false;
  List<String> _errorMessages = [];
  int _successfulCreations = 0;
  List<UserModel> _virtualUsers = [];
  
  // State for individual operations
  bool _isDeleting = false;
  String? _deleteError;
  
  bool get isLoading => _isLoading;
  bool get isDeleting => _isDeleting;
  List<String> get errorMessages => _errorMessages;
  String? get deleteError => _deleteError;
  int get successfulCreations => _successfulCreations;
  List<UserModel> get virtualUsers => _virtualUsers;
  
  VirtualUserProvider(this._service);
  
  // ==================== BULK CREATION METHODS ====================
  
  /// Create multiple virtual users at once
  Future<void> createMultipleUsers(
    String communityId,
    String adminUid,
    List<Map<String, dynamic>> users,
  ) async {
    _isLoading = true;
    _errorMessages.clear();
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
          _errorMessages.add('User ${i + 1}: Name is required');
          continue;
        }
        
        if (name.length < 2) {
          _errorMessages.add('User ${i + 1}: Name must be at least 2 characters');
          continue;
        }
        
        if (phone.isNotEmpty && !_isValidPhoneNumber(phone)) {
          _errorMessages.add('User ${i + 1}: Invalid phone number format');
          continue;
        }
        
        if (email.isNotEmpty && !_isValidEmail(email)) {
          _errorMessages.add('User ${i + 1}: Invalid email format');
          continue;
        }

        usersData.add({
          'name': name.trim(),
          'phone': phone.isNotEmpty ? phone : null,
          'email': email.isNotEmpty ? email : null,
        });
      }

      if (_errorMessages.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (usersData.isEmpty) {
        _errorMessages.add('No valid users to create');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Call the service method
      final createdUsers = await _service.createMultipleVirtualUsers(
        communityId: communityId,
        adminUid: adminUid,
        usersData: usersData,
      );
      
      _successfulCreations = createdUsers.length;
      _virtualUsers.addAll(createdUsers);
      
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

      // Call the service method
      final user = await _service.createVirtualUser(
        communityId: communityId,
        displayName: displayName.trim(),
        adminUid: adminUid,
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
  
  // ==================== UPDATE METHODS ====================
  
  /// Update a virtual user
  Future<bool> updateVirtualUser({
    required String userId,
    required String displayName,
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
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessages.add('Failed to update user: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
}