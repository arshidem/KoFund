// lib/features/issues/services/issue_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:kofund/features/issues/models/issue_model.dart';

class IssueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<IssueModel> createIssue({
    required String title,
    required String description,
    required String type,
    required String userId,
    String? stepsToReproduce,
    String? screenshotUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to report issues');
      }

      final issueId = _firestore.collection('issues').doc().id;
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = _getPlatform();

      final issue = IssueModel(
        id: issueId,
        title: title,
        description: description,
        type: type,
        stepsToReproduce: stepsToReproduce,
        screenshotUrl: screenshotUrl,
        reporterId: currentUser.uid,
        reporterEmail: currentUser.email ?? 'No email',
        reporterName: currentUser.displayName ?? 'Anonymous User',
        status: 'pending',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        appVersion: packageInfo.version,
        platform: platform,
      );

      await _firestore
          .collection('issues')
          .doc(issueId)
          .set(issue.toMap());

      return issue;
    } catch (e) {
      throw Exception('Failed to create issue: $e');
    }
  }

  Stream<List<IssueModel>> getIssuesStream({
    String? statusFilter,
    bool sortByNewest = true,
  }) {
    Query query = _firestore.collection('issues');
    
    if (statusFilter != null && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    
    query = query.orderBy('createdAt', descending: sortByNewest);
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => IssueModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<IssueModel>> getIssues({
    String? statusFilter,
    bool sortByNewest = true,
  }) async {
    Query query = _firestore.collection('issues');
    
    if (statusFilter != null && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    
    query = query.orderBy('createdAt', descending: sortByNewest).limit(20);
    
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => IssueModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required String newStatus,
  }) async {
    try {
      await _firestore.collection('issues').doc(issueId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update issue status: $e');
    }
  }

  Future<void> assignIssueToDeveloper({
    required String issueId,
    required String developerId,
    required String developerName,
  }) async {
    try {
      await _firestore.collection('issues').doc(issueId).update({
        'assignedDeveloperId': developerId,
        'assignedDeveloperName': developerName,
        'status': 'in-progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to assign issue: $e');
    }
  }

  Future<void> addResolutionNotes({
    required String issueId,
    required String notes,
  }) async {
    try {
      await _firestore.collection('issues').doc(issueId).update({
        'resolutionNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add resolution notes: $e');
    }
  }

  Future<IssueModel?> getIssueById(String issueId) async {
    try {
      final doc = await _firestore.collection('issues').doc(issueId).get();
      if (doc.exists) {
        return IssueModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get issue: $e');
    }
  }
 Stream<List<IssueModel>> getUserIssuesStream(String userId) {
    return _firestore
        .collection('issues')
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<List<IssueModel>> getUserIssues(String userId) async {
    final snapshot = await _firestore
        .collection('issues')
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    
    return snapshot.docs
        .map((doc) => IssueModel.fromMap(doc.data()))
        .toList();
  }
  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'desktop';
    }
    return 'web';
  }
}
