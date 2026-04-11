import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? communityId;
  final String? communityName;
  final String role;
  final bool isApproved;
  final bool isAdmin;
  final bool isDeveloper;
  final bool isVirtualUser;
  final String? createdBy; // Who created this virtual user (admin UID)
  final String? createdByName; // 🆕 ADD THIS: admin's display name
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? approvedAt;
  final bool showDetailedProfile;
  final bool notificationsEnabled;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.communityId,
    this.communityName,
    this.role = 'member',
    this.isApproved = false,
    this.isAdmin = false,
    this.isDeveloper = false,
    this.isVirtualUser = false,
    this.createdBy, // 🆕 Keep this for UID reference
    this.createdByName, // 🆕 ADD THIS - for displaying admin name without extra query
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.showDetailedProfile = false,
    this.notificationsEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'communityId': communityId,
      'communityName': communityName,
      'role': role,
      'isApproved': isApproved,
      'isAdmin': isAdmin,
      'isDeveloper': isDeveloper,
      'isVirtualUser': isVirtualUser,
      'createdBy': createdBy,
      'createdByName': createdByName, // 🆕 ADD THIS
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'approvedAt': approvedAt,
      'showDetailedProfile': showDetailedProfile,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Helper function to parse Timestamp
    Timestamp? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
      if (value is String) {
        try {
          return Timestamp.fromMillisecondsSinceEpoch(int.parse(value));
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? map['name'],
      phoneNumber: map['phoneNumber'],
      communityId: map['communityId'],
      communityName: map['communityName'],
      role: map['role'] ?? 'member',
      isApproved: map['isApproved'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      isDeveloper: map['isDeveloper'] ?? false,
      isVirtualUser: map['isVirtualUser'] ?? false,
      createdBy: map['createdBy'],
      createdByName: map['createdByName'], // 🆕 ADD THIS
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      approvedAt: parseTimestamp(map['approvedAt']),
      showDetailedProfile: map['showDetailedProfile'] ?? false,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? communityId,
    String? communityName,
    String? role,
    bool? isApproved,
    bool? isAdmin,
    bool? isDeveloper,
    bool? isVirtualUser,
    String? createdBy,
    String? createdByName, // 🆕 ADD THIS
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? approvedAt,
    bool? showDetailedProfile,
    bool? notificationsEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      communityId: communityId ?? this.communityId,
      communityName: communityName ?? this.communityName,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      isAdmin: isAdmin ?? this.isAdmin,
      isDeveloper: isDeveloper ?? this.isDeveloper,
      isVirtualUser: isVirtualUser ?? this.isVirtualUser,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName, // 🆕 ADD THIS
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      showDetailedProfile: showDetailedProfile ?? this.showDetailedProfile,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  // Helper methods
  
  // 🆕 ADD THIS: Get creator name with fallback
  String get creatorDisplayName {
    if (createdByName != null && createdByName!.isNotEmpty) {
      return createdByName!;
    }
    if (createdBy != null) {
      // Fallback - could be the email or part of UID
      return 'Admin';
    }
    return 'System';
  }

  bool get canAccessApp {
    // Virtual users cannot access app
    if (isVirtualUser) return false;
    return isApproved && communityId != null && communityId!.isNotEmpty;
  }

  // Virtual user helper methods
  bool get canBeDeleted => isVirtualUser;
  bool get canBeEditedByAdmin => isVirtualUser;
  bool get requiresNoAuth => isVirtualUser;
  
  // Combined permissions
  bool get canManageUsers => isAdmin || isDeveloper;
  bool get canAccessAdminFeatures => isAdmin || isDeveloper;
  bool get canManageVirtualUsers => isAdmin; // Only admins can manage virtual users
  
  // Check if this is a real registered user
  bool get isRealUser => !isVirtualUser;

  // 🆕 ADD THIS: Check if this user was created by a specific admin
  bool wasCreatedBy(String adminUid) {
    return createdBy == adminUid;
  }

  // 🆕 ADD THIS: Format for display in UI lists
  String get displayInfo {
    if (isVirtualUser) {
      return '$displayName (Virtual)';
    }
    return displayName ?? email;
  }

  // 🆕 ADD THIS: Get creation info for display
  String get creationInfo {
    if (!isVirtualUser || createdByName == null) {
      return 'Regular user';
    }
    return 'Created by $createdByName';
  }
}
