import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kofund/features/community/models/community_model.dart';
import 'package:kofund/core/constants/firebase_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_Types.dart';

class CommunityFirestoreService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  
  // ✅ CONSTANTS FOR CONSISTENT LINK FORMAT
  static const String _appScheme = 'kofund';
  static const String _appJoinPath = 'join';
  
String _generateInviteLink(String inviteCode, String communityId) {
  // Create a dynamic link
  return 'https://kofund-153ba.web.app/join/$inviteCode';
}
  /// ✅ Create new community with consistent invite link
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
    final docRef = _firestore.collection(FirebaseKeys.communities).doc();
    final inviteCode = await _generateUniqueInviteCode();
    final inviteLink = _generateInviteLink(inviteCode, docRef.id); // ✅ Consistent format

    final community = CommunityModel(
      communityId: docRef.id,
      name: name,
      type: type,
      description: description,
      inviteCode: inviteCode,
      inviteLink: inviteLink,
      createdBy: adminId,
      createdByName: adminName,
      createdAt: Timestamp.now(),
      totalMembers: 1,
      pendingMembers: 0,
      status: 'active',
      location: location != null ? {'address': location} : null,
      settings: settings ?? _getDefaultSettings(),
      logoUrl: logoUrl,
    );

    final batch = _firestore.batch();
    
    // 1. Create community document
    batch.set(docRef, community.toMap());
    
    // 2. Add admin to community members collection
    final memberRef = docRef.collection(FirebaseKeys.members).doc(adminId);
    batch.set(memberRef, {
      'userId': adminId,
      'email': adminEmail,
      'name': adminName,
      'role': 'admin',
      'isApproved': true,
      'approvedAt': Timestamp.now(),
      'joinedAt': Timestamp.now(),
    });
    
    // 3. Update user document
    final userRef = _firestore.collection('users').doc(adminId);
    batch.update(userRef, {
      'communityId': community.communityId,
      'communityCode': community.inviteCode,
      'communityName': community.name,
      'role': 'admin',
      'isAdmin': true,
      'isApproved': true,
      'approvedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();
    return community;
  }

  /// ✅ Simple default settings
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'notifications': true,
      'financialTransparency': true,
      'memberCanCreateEvents': false,
      'autoArchiveEvents': true,
      'requireApproval': true,
      'isPublic': false,
    };
  }

  /// ✅ Regenerate invite code with consistent link
  Future<void> regenerateInviteCode(String communityId) async {
    final newCode = await _generateUniqueInviteCode();
    final newInviteLink = _generateInviteLink(newCode, communityId);

    await _firestore.collection(FirebaseKeys.communities).doc(communityId).update({
      'inviteCode': newCode,
      'inviteLink': newInviteLink,
      'lastActivityAt': Timestamp.now(),
    });
  }

  /// ✅ Generate unique 8-character invite code
  Future<String> _generateUniqueInviteCode() async {
    String code = '';
    bool exists = true;

    while (exists) {
      code = _generateRandomCode(8);
      final query = await _firestore
          .collection(FirebaseKeys.communities)
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      exists = query.docs.isNotEmpty;
    }
    return code;
  }

  /// ✅ Generate random alphanumeric string
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// ✅ Get community by invite code
  Future<CommunityModel?> getCommunityByCode(String code) async {
    final query = await _firestore
        .collection(FirebaseKeys.communities)
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    return query.docs.isNotEmpty
        ? CommunityModel.fromMap(query.docs.first.data(), query.docs.first.id)
        : null;
  }

  /// ✅ Generate and set invite link (consistent format)
  Future<String> generateInviteLink({
    required String communityId,
  }) async {
    try {
      final community = await getCommunityById(communityId);
      if (community == null) {
        throw Exception('Community not found');
      }

      final inviteLink = _generateInviteLink(community.inviteCode, communityId);
      
      await _firestore.collection(FirebaseKeys.communities).doc(communityId).update({
        'inviteLink': inviteLink,
        'lastActivityAt': Timestamp.now(),
      });

      return inviteLink;
    } catch (e) {
      throw Exception('Failed to generate invite link: $e');
    }
  }

  /// ✅ Regenerate both code and link
  Future<void> regenerateInviteCodeAndLink(String communityId) async {
    try {
      final batch = _firestore.batch();
      final communityRef = _firestore.collection(FirebaseKeys.communities).doc(communityId);

      final newInviteCode = await _generateUniqueInviteCode();
      final newInviteLink = _generateInviteLink(newInviteCode, communityId);

      batch.update(communityRef, {
        'inviteCode': newInviteCode,
        'inviteLink': newInviteLink,
        'lastActivityAt': Timestamp.now(),
      });

      // Update all members with new code
      final membersSnapshot = await communityRef.collection(FirebaseKeys.members).get();
      for (final memberDoc in membersSnapshot.docs) {
        final userRef = _firestore.collection('users').doc(memberDoc.id);
        batch.update(userRef, {
          'communityCode': newInviteCode,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Get or create invite link
  Future<String> getOrCreateInviteLink(String communityId) async {
    try {
      final doc = await _firestore.collection(FirebaseKeys.communities).doc(communityId).get();
      
      if (!doc.exists) {
        throw Exception('Community not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      if (data['inviteLink'] != null && data['inviteLink'].toString().isNotEmpty) {
        return data['inviteLink'];
      }

      final inviteCode = data['inviteCode'] ?? '';
      if (inviteCode.isEmpty) {
        throw Exception('No invite code found for community');
      }

      final newInviteLink = _generateInviteLink(inviteCode, communityId);
      
      await _firestore.collection(FirebaseKeys.communities).doc(communityId).update({
        'inviteLink': newInviteLink,
        'lastActivityAt': Timestamp.now(),
      });

      return newInviteLink;
    } catch (e) {
      throw Exception('Failed to get invite link: $e');
    }
  }

  /// ✅ Join community using invite code
  Future<void> joinCommunityWithCode({
    required String userId,
    required String userEmail,
    required String userName,
    required String inviteCode,
  }) async {
    try {
      final query = await _firestore
          .collection(FirebaseKeys.communities)
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Invalid invite code');
      }

      final communityDoc = query.docs.first;
      final communityId = communityDoc.id;
      final communityData = communityDoc.data();

      final existingMember = await _firestore
          .collection(FirebaseKeys.communities)
          .doc(communityId)
          .collection(FirebaseKeys.members)
          .doc(userId)
          .get();

      if (existingMember.exists) {
        throw Exception('You are already a member of this community');
      }

      final batch = _firestore.batch();
      final communityRef = _firestore.collection(FirebaseKeys.communities).doc(communityId);
      final memberRef = communityRef.collection(FirebaseKeys.members).doc(userId);
      final userRef = _firestore.collection('users').doc(userId);

      batch.set(memberRef, {
        'userId': userId,
        'email': userEmail,
        'name': userName,
        'role': 'member',
        'isApproved': false,
        'joinedAt': Timestamp.now(),
        'requestedAt': Timestamp.now(),
      });

      batch.update(userRef, {
        'communityId': communityId,
        'communityCode': inviteCode,
        'communityName': communityData['name'],
        'role': 'member',
        'isApproved': false,
        'isAdmin': false,
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      // 🔔 Trigger Notification to Admins (New Member Pending Approval)
      try {
        final notificationService = NotificationService();
        // Fire and forget, don't await to speed up UI navigation
        notificationService.sendCommunityNotification(
          communityId: communityId,
          title: 'New Join Request 👤',
          body: '$userName wants to join ${communityData['name']}. Review now.',
          type: NotificationType.pendingUser,
          targetRole: 'admin',
          data: {
            'memberName': userName,
            'communityName': communityData['name'] ?? 'the community',
            'requestedAt': DateFormat('MMM dd, yyyy · hh:mm a').format(DateTime.now()),
            'pendingUserId': userId, // ✅ Use pendingUserId to avoid confusion with recipient or sender
            'communityId': communityId,
          },
        ).catchError((e) {
          debugPrint('⚠️ Admin notification background failed: $e');
        });
      } catch (e) {
        debugPrint('⚠️ Admin notification setup failed: $e');
      }

    } catch (e) {
      rethrow;
    }
  }

Future<void> joinCommunityWithLink({
  required String userId,
  required String userEmail,
  required String userName,
  required String inviteLink,
}) async {
  try {
    final uri = Uri.parse(inviteLink);
    
    // ✅ Handle new format: kofund://join?code=CUOVUA3H
    if (uri.scheme != 'kofund') {
      throw Exception('Invalid invite link format');
    }

    String? inviteCode;
    
    // Get code from query parameters
    if (uri.queryParameters.containsKey('code')) {
      inviteCode = uri.queryParameters['code'];
    } 
    // Fallback: get from path if needed
    else if (uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      if (lastSegment.length >= 8) {
        inviteCode = lastSegment;
      }
    }
    
    if (inviteCode == null || inviteCode.isEmpty) {
      throw Exception('No invite code found in link');
    }

    // Join using the code
    await joinCommunityWithCode(
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      inviteCode: inviteCode,
    );
  } catch (e) {
    rethrow;
  }
}
  /// ✅ Get community by ID
  Future<CommunityModel?> getCommunityById(String communityId) async {
    final doc = await _firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .get();

    return doc.exists ? CommunityModel.fromMap(doc.data()!, doc.id) : null;
  }

  /// ✅ Stream community updates
  Stream<CommunityModel?> getCommunityStream(String communityId) {
    return _firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .snapshots()
        .map((doc) => doc.exists ? CommunityModel.fromMap(doc.data()!, doc.id) : null);
  }

  /// ✅ Check if user is part of a community
  Future<bool> isUserInCommunity(String userId, String communityId) async {
    final doc = await _firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .doc(userId)
        .get();
    return doc.exists;
  }

  /// ✅ Get all communities for a user
  Future<List<CommunityModel>> getUserCommunities(String userId) async {
    final membersQuery = await _firestore
        .collectionGroup(FirebaseKeys.members)
        .where('userId', isEqualTo: userId)
        .get();

    final communityIds =
        membersQuery.docs.map((doc) => doc.reference.parent.parent!.id).toList();

    if (communityIds.isEmpty) return [];

    final communitiesQuery = await _firestore
        .collection(FirebaseKeys.communities)
        .where(FieldPath.documentId, whereIn: communityIds)
        .get();

    return communitiesQuery.docs
        .map((doc) => CommunityModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// ✅ Update community details
  Future<void> updateCommunity({
    required String communityId,
    required String name,
    required String type,
    required String description,
    String? location,
    Map<String, dynamic>? settings,
    String? logoUrl,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'type': type,
      'description': description,
      'lastActivityAt': Timestamp.now(),
    };

    if (location != null) updates['location'] = {'address': location};
    if (settings != null) updates['settings'] = settings;
    if (logoUrl != null) updates['logoUrl'] = logoUrl;

    await _firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .update(updates);
  }

  /// ✅ Delete a community
  Future<void> deleteCommunity(String communityId) async {
    await _firestore.collection(FirebaseKeys.communities).doc(communityId).delete();
  }

  /// ✅ Stream all community members
  Stream<List<Map<String, dynamic>>> getCommunityMembers(String communityId) {
    return _firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  /// ✅ Add member
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

  /// ✅ Remove member
  Future<void> removeMemberFromCommunity(String communityId, String userId) async {
    await _firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .doc(userId)
        .delete();

    await _decrementTotalMembers(communityId);
  }

  /// ✅ Update member role
  Future<void> updateMemberRole({
    required String communityId,
    required String userId,
    required String role,
  }) async {
    await _firestore
        .collection(FirebaseKeys.communities)
        .doc(communityId)
        .collection(FirebaseKeys.members)
        .doc(userId)
        .update({'role': role});
  }

  /// ✅ Check if user can invite members (admin only)
  Future<bool> canUserInviteMembers({
    required String userId,
    required String communityId,
  }) async {
    try {
      final memberDoc = await _firestore
          .collection(FirebaseKeys.communities)
          .doc(communityId)
          .collection(FirebaseKeys.members)
          .doc(userId)
          .get();

      if (!memberDoc.exists) return false;

      final memberData = memberDoc.data() as Map<String, dynamic>;
      final role = memberData['role'] ?? 'member';
      
      return role == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// ✅ Get community invite statistics (Optimized count)
  Future<Map<String, dynamic>> getInviteStats(String communityId) async {
    try {
      final communityDoc = await _firestore
          .collection(FirebaseKeys.communities)
          .doc(communityId)
          .get();
 
      if (!communityDoc.exists) {
        throw Exception('Community not found');
      }
 
      final communityData = communityDoc.data() as Map<String, dynamic>;
      
      // 🚀 OPTIMIZATION: Use count() aggregation instead of full query for pending requests
      // Note: count() only charges 1 read per 1000 docs (or similar small amount)
      final pendingAggregate = await _firestore
          .collection(FirebaseKeys.communities)
          .doc(communityId)
          .collection(FirebaseKeys.members)
          .where('isApproved', isEqualTo: false)
          .count()
          .get();
 
      return {
        'inviteCode': communityData['inviteCode'] ?? '',
        'inviteLink': communityData['inviteLink'] ?? '',
        'totalMembers': communityData['totalMembers'] ?? 0,
        'pendingMembers': communityData['pendingMembers'] ?? 0,
        'pendingRequests': pendingAggregate.count,
        'lastRefreshed': communityData['lastActivityAt'],
      };
    } catch (e) {
      throw Exception('Failed to get invite stats: $e');
    }
  }

  // ---------------------- 🔒 Private Helpers ----------------------

  Future<void> _addCommunityMember(
      String communityId, String userId, String email, String name, String role) async {
    await _firestore
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
    await _firestore.collection(FirebaseKeys.communities).doc(communityId).update({
      'totalMembers': FieldValue.increment(1),
      'lastActivityAt': Timestamp.now(),
    });
  }

  Future<void> _decrementTotalMembers(String communityId) async {
    await _firestore.collection(FirebaseKeys.communities).doc(communityId).update({
      'totalMembers': FieldValue.increment(-1),
      'lastActivityAt': Timestamp.now(),
    });
  }
}





