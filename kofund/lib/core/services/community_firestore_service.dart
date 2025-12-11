import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/community/models/community_model.dart';
import 'package:kofund/core/constants/firebase_keys.dart';

class CommunityFirestoreService {
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

Future<CommunityModel> createCommunity({
  required String name,
  required String type,
  required String description,
  required String adminEmail,
  required String adminId,
  required String adminName,
  String? location,
  Map<String, dynamic>? settings,
  String? logoUrl,
}) async {
  final docRef = firestore.collection(FirebaseKeys.communities).doc();
  final inviteCode = await _generateUniqueInviteCode();

  final community = CommunityModel(
    communityId: docRef.id,
    name: name,
    type: type,
    description: description,
    inviteCode: inviteCode,
    createdBy: adminId,
    createdByName: adminName,
    createdAt: Timestamp.now(),
    totalMembers: 1, // ✅ Admin is first approved member
    pendingMembers: 0, // ✅ Starts with 0 pending members
    status: 'active',
    location: location != null ? {'address': location} : null,
    settings: settings ?? _getDefaultSettings(),
    logoUrl: logoUrl,
  );

  final batch = firestore.batch();
  
  // 1. Create community document
  batch.set(docRef, community.toMap());
  
  // 2. Add admin to community members collection (Auto-approved)
  final memberRef = docRef.collection(FirebaseKeys.members).doc(adminId);
  batch.set(memberRef, {
    'userId': adminId,
    'email': adminEmail,
    'name': adminName,
    'role': 'admin',
    'isApproved': true, // ✅ Admin is auto-approved
    'approvedAt': Timestamp.now(),
    'joinedAt': Timestamp.now(),
  });
  
  // 3. Update user document with community info
  final userRef = firestore.collection('users').doc(adminId);
  batch.update(userRef, {
    'communityId': community.communityId,
    'communityCode': community.inviteCode,
    'communityName': community.name,
    'communityType': community.type,
    'role': 'admin',
    'isAdmin': true,
    'isApproved': true, // ✅ Admin is auto-approved
    'approvedAt': Timestamp.now(),
  });

  await batch.commit();
  return community;
}

// ✅ Simple default settings - ALL require approval
Map<String, dynamic> _getDefaultSettings() {
  return {
    'notifications': true,
    'financialTransparency': true,
    'memberCanCreateEvents': false, // Only admins can create events
    'autoArchiveEvents': true,
    'requireApproval': true, // ✅ ALL communities require manual approval
    'isPublic': false, // ✅ ALL communities are private
  };
}
  /// 🔁 Regenerate a unique invite code for an existing community
  Future<void> regenerateInviteCode(String communityId) async {
    final newCode = await _generateUniqueInviteCode();

    await firestore.collection(FirebaseKeys.communities).doc(communityId).update({
      'inviteCode': newCode,
      'lastActivityAt': Timestamp.now(),
    });
  }

  /// 🔐 Generate unique 8-character invite code
Future<String> _generateUniqueInviteCode() async {
  String code = ''; // ✅ Initialize with empty string
  bool exists = true;

  while (exists) {
    code = _generateRandomCode(8); // 👈 8-character alphanumeric
    final query = await firestore
        .collection(FirebaseKeys.communities)
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    exists = query.docs.isNotEmpty;
  }
  return code;
}

  /// 🧩 Generate random alphanumeric string
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 🔎 Get community by invite code
  Future<CommunityModel?> getCommunityByCode(String code) async {
    final query = await firestore
        .collection(FirebaseKeys.communities)
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    return query.docs.isNotEmpty
        ? CommunityModel.fromMap(query.docs.first.data(), query.docs.first.id)
        : null;
  }

  /// 🔎 Get community by ID
  Future<CommunityModel?> getCommunityById(String communityId) async {
    final doc = await firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .get();

    return doc.exists ? CommunityModel.fromMap(doc.data()!, doc.id) : null;
  }

  /// 📡 Stream community updates
  Stream<CommunityModel?> getCommunityStream(String communityId) {
    return firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .snapshots()
        .map((doc) => doc.exists ? CommunityModel.fromMap(doc.data()!, doc.id) : null);
  }

  /// 👥 Check if user is part of a community
  Future<bool> isUserInCommunity(String userId, String communityId) async {
    final doc = await firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .doc(userId)
        .get();
    return doc.exists;
  }

  /// 📋 Get all communities for a user
  Future<List<CommunityModel>> getUserCommunities(String userId) async {
    final membersQuery = await firestore
        .collectionGroup(FirebaseKeys.members)
        .where('userId', isEqualTo: userId)
        .get();

    final communityIds =
        membersQuery.docs.map((doc) => doc.reference.parent.parent!.id).toList();

    if (communityIds.isEmpty) return [];

    final communitiesQuery = await firestore
        .collection(FirebaseKeys.communities)
        .where(FieldPath.documentId, whereIn: communityIds)
        .get();

    return communitiesQuery.docs
        .map((doc) => CommunityModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// 🛠️ Update community details
/// 🛠️ Update community details
Future<void> updateCommunity({
  required String communityId,
  required String name, // ✅ This is the parameter
  required String type,
  required String description,
  String? location,
  Map<String, dynamic>? settings,
  String? logoUrl,
}) async {
  final updates = <String, dynamic>{
    'name': name, // ✅ FIXED: Use 'name' parameter, not 'displayName'
    'type': type,
    'description': description,
    'lastActivityAt': Timestamp.now(),
  };

  if (location != null) updates['location'] = {'address': location};
  if (settings != null) updates['settings'] = settings;
  if (logoUrl != null) updates['logoUrl'] = logoUrl;

  await firestore
      .collection(FirebaseKeys.communities)
      .doc(communityId)
      .update(updates);
}

  /// ❌ Delete a community
  Future<void> deleteCommunity(String communityId) async {
    await firestore.collection(FirebaseKeys.communities).doc(communityId).delete();
  }

  /// 👥 Stream all community members
  Stream<List<Map<String, dynamic>>> getCommunityMembers(String communityId) {
    return firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  /// ➕ Add member
  Future<void> addMemberToCommunity({
    required String communityId,
    required String userId,
    required String userEmail,
    required String userName,
    required String role,
  }) async {
    await _addCommunityMember(communityId, userId, userEmail, userName, role);
    await _incrementTotalMembers(communityId);
  }

  /// ➖ Remove member
  Future<void> removeMemberFromCommunity(String communityId, String userId) async {
    await firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .doc(userId)
        .delete();

    await _decrementTotalMembers(communityId);
  }

  /// 🔄 Update member role
  Future<void> updateMemberRole({
    required String communityId,
    required String userId,
    required String role,
  }) async {
    await firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .doc(userId)
        .update({'role': role});
  }

  // ---------------------- 🔒 Private Helpers ----------------------



  Future<void> _addCommunityMember(
      String communityId, String userId, String email, String name, String role) async {
    await firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .doc(userId)
        .set({
      'userId': userId,
      'email': email,
      'name': name,
      'role': role,
      'joinedAt': Timestamp.now(),
    });
  }

  Future<void> _incrementTotalMembers(String communityId) async {
    await firestore.collection(FirebaseKeys.communities).doc(communityId).update({
      'totalMembers': FieldValue.increment(1),
      'lastActivityAt': Timestamp.now(),
    });
  }

  Future<void> _decrementTotalMembers(String communityId) async {
    await firestore.collection(FirebaseKeys.communities).doc(communityId).update({
      'totalMembers': FieldValue.increment(-1),
      'lastActivityAt': Timestamp.now(),
    });
  }
}
