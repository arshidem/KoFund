import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? communityId;
  final String? communityName; // 🆕 ADD THIS FIELD
  final String role;
  final bool isApproved;
  final bool isAdmin;
  final bool emailVerified; // 🆕 ADD THIS FIELD FOR EMAIL VERIFICATION
  final Timestamp? createdAt;
  final Timestamp? updatedAt; // 🆕 ADD THIS FIELD
  final Timestamp? approvedAt; // 🆕 ADD THIS FIELD
  final bool showDetailedProfile;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.communityId,
    this.communityName, // 🆕 ADD THIS
    this.role = 'member',
    this.isApproved = false,
    this.isAdmin = false,
    this.emailVerified = false, // 🆕 ADD THIS - default false
    this.createdAt,
    this.updatedAt, // 🆕 ADD THIS
    this.approvedAt, // 🆕 ADD THIS
    this.showDetailedProfile = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'communityId': communityId,
      'communityName': communityName, // 🆕 ADD THIS
      'role': role,
      'isApproved': isApproved,
      'isAdmin': isAdmin,
      'emailVerified': emailVerified, // 🆕 ADD THIS
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(), // 🆕 ADD THIS
      'approvedAt': approvedAt, // 🆕 ADD THIS
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
      communityName: map['communityName'], // 🆕 ADD THIS
      role: map['role'] ?? 'member',
      isApproved: map['isApproved'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      emailVerified: map['emailVerified'] ?? false, // 🆕 ADD THIS
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']), // 🆕 ADD THIS
      approvedAt: _parseTimestamp(map['approvedAt']), // 🆕 ADD THIS
      showDetailedProfile: map['showDetailedProfile'] ?? false,
    );
  }

  // ✅ UPDATED copyWith method
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? communityId,
    String? communityName, // 🆕 ADD THIS
    String? role,
    bool? isApproved,
    bool? isAdmin,
    bool? emailVerified, // 🆕 ADD THIS
    Timestamp? createdAt,
    Timestamp? updatedAt, // 🆕 ADD THIS
    Timestamp? approvedAt, // 🆕 ADD THIS
    bool? showDetailedProfile,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      communityId: communityId ?? this.communityId,
      communityName: communityName ?? this.communityName, // 🆕 ADD THIS
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      isAdmin: isAdmin ?? this.isAdmin,
      emailVerified: emailVerified ?? this.emailVerified, // 🆕 ADD THIS
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt, // 🆕 ADD THIS
      approvedAt: approvedAt ?? this.approvedAt, // 🆕 ADD THIS
      showDetailedProfile: showDetailedProfile ?? this.showDetailedProfile,
    );
  }

  // Helper method to check if user can access the app
  bool get canAccessApp {
    return emailVerified && isApproved && communityId != null && communityId!.isNotEmpty;
  }

  // Helper method to check if user needs email verification
  bool get needsEmailVerification {
    return !emailVerified;
  }

  // Helper method to check if user is waiting for community approval
  bool get waitingForApproval {
    return emailVerified && communityId != null && communityId!.isNotEmpty && !isApproved;
  }

  // Helper method to check if user needs to join community
  bool get needsToJoinCommunity {
    return emailVerified && (communityId == null || communityId!.isEmpty);
  }
}