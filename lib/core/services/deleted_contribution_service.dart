// 📁 lib/core/services/deleted_contribution_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/contributions/models/contribution_model.dart';
import '../../features/contributions/models/deleted_contribution_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class DeletedContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔹 Move a contribution to deleted_contributions collection
  Future<void> moveToDeletedContributions({
    required ContributionModel contribution,
    required String adminId,
    required String adminName,
    required String reason,
  }) async {
    try {
      debugPrint('🔄 Starting secure deletion process...');
      
      // 1. Generate unique ID for deleted record
      final deletedId = 'deleted_${contribution.contributionId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // 2. Create deleted record with TTL
      final deletedRecord = DeletedContributionModel.fromContributionModel(
        contribution: contribution,
        deletedByUserId: adminId,
        deletedByUserName: adminName,
        deletionReason: reason,
      );
      
      debugPrint('📝 Created deleted record with TTL expiry: ${deletedRecord.formattedTTLExpiry}');
      
      // 3. Save to separate collection
      await _firestore
          .collection('deleted_contributions')
          .doc(deletedId)
          .set(deletedRecord.toMap());
      
      debugPrint('✅ Saved to deleted_contributions collection');
      
      // 4. Delete from original contributions collection
      await _firestore
          .collection('contributions')
          .doc(contribution.contributionId)
          .delete();
      
      debugPrint('🗑️ Removed from contributions collection');
      
      // 5. Create notification for member
      await _createDeletionNotification(deletedRecord);
      
      debugPrint('🎯 Deletion process completed successfully');
      
    } catch (e) {
      debugPrint('❌ Error in moveToDeletedContributions: $e');
      rethrow;
    }
  }

  // 🔹 Get deleted contributions for a specific user
  Stream<List<DeletedContributionModel>> getUserDeletedContributions({
    required String userId,
    required String communityId,
  }) {
    return _firestore
        .collection('deleted_contributions')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .where('isRestored', isEqualTo: false)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeletedContributionModel.fromMap(
                  doc.data(),
                  doc.id,
                ))
            .toList());
  }

  // 🔹 Get all deleted contributions in community (admin view)
  Stream<List<DeletedContributionModel>> getAllDeletedContributions({
    required String communityId,
  }) {
    return _firestore
        .collection('deleted_contributions')
        .where('communityId', isEqualTo: communityId)
        .where('isRestored', isEqualTo: false)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeletedContributionModel.fromMap(
                  doc.data(),
                  doc.id,
                ))
            .toList());
  }

  // 🔹 Restore a deleted contribution (admin only)
  Future<void> restoreDeletedContribution({
    required String deletedRecordId,
    required String adminId,
    required String adminName,
  }) async {
    try {
      // 1. Get the deleted record
      final deletedDoc = await _firestore
          .collection('deleted_contributions')
          .doc(deletedRecordId)
          .get();
      
      if (!deletedDoc.exists) {
        throw Exception('Deleted record not found');
      }
      
      final deletedRecord = DeletedContributionModel.fromMap(
        deletedDoc.data() as Map<String, dynamic>,
        deletedRecordId,
      );
      
      // 2. Check if can be restored
      if (!deletedRecord.canBeRestored) {
        throw Exception('Cannot restore - already restored or expired');
      }
      
      // 3. Convert back to ContributionModel
      final restoredContribution = deletedRecord.toContributionModel();
      
      // 4. Add back to contributions collection
      await _firestore
          .collection('contributions')
          .doc(restoredContribution.contributionId)
          .set(restoredContribution.toMap());
      
      debugPrint('✅ Restored to contributions collection');
      
      // 5. Mark as restored in deleted_contributions
      await deletedDoc.reference.update({
        'isRestored': true,
        'restoredByUserId': adminId,
        'restoredByUserName': adminName,
        'restoredAt': Timestamp.now(),
        'ttlExpiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: 7))), // Short TTL for restored records
      });
      
      debugPrint('📝 Marked as restored in deleted_contributions');
      
      // 6. Create restoration notification
      await _createRestorationNotification(deletedRecord, adminName);
      
      debugPrint('🎯 Restoration completed successfully');
      
    } catch (e) {
      debugPrint('❌ Error restoring contribution: $e');
      rethrow;
    }
  }

  // 🔹 Get deleted contribution by ID
  Future<DeletedContributionModel?> getDeletedContributionById(String deletedId) async {
    try {
      final doc = await _firestore
          .collection('deleted_contributions')
          .doc(deletedId)
          .get();
      
      if (!doc.exists) return null;
      
      return DeletedContributionModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      debugPrint('❌ Error getting deleted contribution: $e');
      return null;
    }
  }

  // 🔹 Private: Create deletion notification
  Future<void> _createDeletionNotification(DeletedContributionModel deletedRecord) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': deletedRecord.userId,
        'title': 'Contribution Deleted',
        'message': 'Admin ${deletedRecord.deletedByUserName} deleted your contribution of ₹${deletedRecord.amount}. Reason: ${deletedRecord.deletionReason}',
        'type': 'contribution_deleted',
        'relatedId': deletedRecord.deletedContributionId,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'data': {
          'amount': deletedRecord.amount,
          'adminName': deletedRecord.deletedByUserName,
          'reason': deletedRecord.deletionReason,
          'originalContributionId': deletedRecord.originalContributionId,
          'deletedAt': deletedRecord.deletedAt,
          'expiresAt': deletedRecord.ttlExpiresAt,
        },
      });
      
      debugPrint('📢 Created deletion notification for user: ${deletedRecord.userId}');
    } catch (e) {
      debugPrint('⚠️ Failed to create notification: $e');
    }
  }

  // 🔹 Private: Create restoration notification
  Future<void> _createRestorationNotification(
    DeletedContributionModel deletedRecord, 
    String restoredByAdminName,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': deletedRecord.userId,
        'title': 'Contribution Restored',
        'message': 'Admin $restoredByAdminName restored your deleted contribution of ₹${deletedRecord.amount}',
        'type': 'contribution_restored',
        'relatedId': deletedRecord.originalContributionId,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'data': {
          'amount': deletedRecord.amount,
          'restoredBy': restoredByAdminName,
          'originalContributionId': deletedRecord.originalContributionId,
        },
      });
      
      debugPrint('📢 Created restoration notification');
    } catch (e) {
      debugPrint('⚠️ Failed to create restoration notification: $e');
    }
  }
  // 🔹 Get deleted contributions for a specific event
Stream<List<DeletedContributionModel>> getDeletedContributions({
  required String eventId,
}) {
  return _firestore
      .collection('deleted_contributions')
      .where('eventId', isEqualTo: eventId)
      .where('isRestored', isEqualTo: false)
      .orderBy('deletedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DeletedContributionModel.fromMap(
                doc.data(),
                doc.id,
              ))
          .toList());
}

  // 🔹 Check if user has deleted contributions
  Future<bool> hasDeletedContributions({
    required String userId,
    required String communityId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('deleted_contributions')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .where('isRestored', isEqualTo: false)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking deleted contributions: $e');
      return false;
    }
  }
}






