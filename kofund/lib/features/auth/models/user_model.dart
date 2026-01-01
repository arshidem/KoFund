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
  final bool isVirtualUser; // 🆕 ADD THIS FIELD
  final String? createdBy; // 🆕 Who created this virtual user (admin UID)
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? approvedAt;
  final bool showDetailedProfile;

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
    this.isVirtualUser = false, // 🆕 ADD THIS - default false
    this.createdBy, // 🆕 ADD THIS
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.showDetailedProfile = false,
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
      'isVirtualUser': isVirtualUser, // 🆕 ADD THIS
      'createdBy': createdBy, // 🆕 ADD THIS
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'approvedAt': approvedAt,
      'showDetailedProfile': showDetailedProfile,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Helper function to parse Timestamp
    Timestamp? _parseTimestamp(dynamic value) {
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
      isVirtualUser: map['isVirtualUser'] ?? false, // 🆕 ADD THIS
      createdBy: map['createdBy'], // 🆕 ADD THIS
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      approvedAt: _parseTimestamp(map['approvedAt']),
      showDetailedProfile: map['showDetailedProfile'] ?? false,
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
    bool? isVirtualUser, // 🆕 ADD THIS
    String? createdBy, // 🆕 ADD THIS
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? approvedAt,
    bool? showDetailedProfile,
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
      isVirtualUser: isVirtualUser ?? this.isVirtualUser, // 🆕 ADD THIS
      createdBy: createdBy ?? this.createdBy, // 🆕 ADD THIS
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      showDetailedProfile: showDetailedProfile ?? this.showDetailedProfile,
    );
  }

  // Helper methods
  bool get canAccessApp {
    // Virtual users cannot access app
    if (isVirtualUser) return false;
    return isApproved && communityId != null && communityId!.isNotEmpty;
  }

  // 🆕 ADD THESE HELPER METHODS FOR VIRTUAL USERS
  bool get canBeDeleted => isVirtualUser; // Only virtual users can be deleted
  bool get canBeEditedByAdmin => isVirtualUser; // Admin can edit virtual users
  bool get requiresNoAuth => isVirtualUser; // No login required
  
  // Combined permissions
  bool get canManageUsers => isAdmin || isDeveloper;
  bool get canAccessAdminFeatures => isAdmin || isDeveloper;
  bool get canManageVirtualUsers => isAdmin; // Only admins can manage virtual users
  
  // Check if this is a real registered user
  bool get isRealUser => !isVirtualUser;
}