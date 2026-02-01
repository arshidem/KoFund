import 'package:cloud_firestore/cloud_firestore.dart'; // 🆕 MAKE SURE THIS IMPORT EXISTS
import 'package:kofund/core/constants/community_types.dart'; // 🆕 ADD THIS

class CommunityModel {
  final String communityId;
  final String name;
  final String type;
  final String? description;
  final String inviteCode;
  final String createdBy;
  final String createdByName;
  final Timestamp createdAt;
  final int totalMembers;
  final int pendingMembers; // 🆕 ADD THIS FIELD
  final String status;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? settings;
  final Timestamp? lastActivityAt;
  final String? logoUrl;
  final String? inviteLink; // 🆕 ADD THIS FIELD IF NEEDED

  CommunityModel({
    required this.communityId,
    required this.name,
    required this.type,
    this.description,
    required this.inviteCode,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.totalMembers = 0,
    this.pendingMembers = 0, // 🆕 ADD THIS DEFAULT VALUE
    this.status = 'active',
    this.location,
    this.settings,
    this.lastActivityAt,
    this.logoUrl,
    this.inviteLink, // 🆕 ADD THIS
  });

  factory CommunityModel.fromMap(Map<String, dynamic> data, String docId) {
    return CommunityModel(
      communityId: docId,
      name: data['name'] ?? '',
      type: data['type'] ?? CommunityType.other,
      description: data['description'],
      inviteCode: data['inviteCode'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      totalMembers: data['totalMembers'] ?? 0,
      pendingMembers: data['pendingMembers'] ?? 0, // 🆕 ADD THIS
      status: data['status'] ?? 'active',
      location: data['location'] != null ? Map<String, dynamic>.from(data['location']) : null,
      settings: data['settings'] != null ? Map<String, dynamic>.from(data['settings']) : null,
      lastActivityAt: data['lastActivityAt'],
      logoUrl: data['logoUrl'],
      inviteLink: data['inviteLink'], // 🆕 ADD THIS
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'totalMembers': totalMembers,
      'pendingMembers': pendingMembers, // 🆕 ADD THIS
      'status': status,
      'location': location,
      'settings': settings,
      'lastActivityAt': lastActivityAt ?? Timestamp.now(),
      'logoUrl': logoUrl,
      'inviteLink': inviteLink, // 🆕 ADD THIS
    };
  }
}
