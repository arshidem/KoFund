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
  final bool isDeveloper; // 🆕 ADD THIS FIELD
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
    this.isDeveloper = false, // 🆕 ADD THIS - default false
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
      'isDeveloper': isDeveloper, // 🆕 ADD THIS
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
      isDeveloper: map['isDeveloper'] ?? false, // 🆕 ADD THIS
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      approvedAt: _parseTimestamp(map['approvedAt']),
      showDetailedProfile: map['showDetailedProfile'] ?? false,
    );
  }

  // ✅ UPDATED copyWith method with isDeveloper
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
    bool? isDeveloper, // 🆕 ADD THIS
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
      isDeveloper: isDeveloper ?? this.isDeveloper, // 🆕 ADD THIS
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      showDetailedProfile: showDetailedProfile ?? this.showDetailedProfile,
    );
  }

  // Helper method to check if user can access the app
  bool get canAccessApp {
    return isApproved && communityId != null && communityId!.isNotEmpty;
  }

  // Helper method to check if user is waiting for community approval
  bool get waitingForApproval {
    return communityId != null && communityId!.isNotEmpty && !isApproved;
  }

  // Helper method to check if user needs to join community
  bool get needsToJoinCommunity {
    return (communityId == null || communityId!.isEmpty);
  }

  // 🆕 ADD THESE HELPER METHODS FOR DEVELOPER ACCESS
  bool get canAccessDeveloperTools => isDeveloper;
  bool get isSuperUser => isDeveloper; // Developer has all access
  bool get canManageDevelopers => isDeveloper; // Only developers can manage developers
  
  // Combined permissions
  bool get canManageUsers => isAdmin || isDeveloper;
  bool get canAccessAdminFeatures => isAdmin || isDeveloper;
}