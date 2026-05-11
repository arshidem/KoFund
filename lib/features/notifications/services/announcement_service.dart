import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AnnouncementService {
  static final _fs = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Fetch all active announcements the current user hasn't read yet.
  static Future<List<Map<String, dynamic>>> getUnreadAnnouncements() async {
    final uid = _uid;
    if (uid == null) return [];

    try {
      // 1. Get all active announcements
      final announcementsSnap = await _fs
          .collection('announcements')
          .where('is_active', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .get();

      if (announcementsSnap.docs.isEmpty) return [];

      // 2. Get the IDs of announcements this user has already read
      final readSnap = await _fs
          .collection('users')
          .doc(uid)
          .collection('read_announcements')
          .get();

      final readIds = readSnap.docs.map((eventId) => eventId.id).toSet();

      // 3. Filter out read announcements
      return announcementsSnap.docs
          .where((eventId) => !readIds.contains(eventId.id))
          .map((eventId) => {'id': eventId.id, ...(eventId.data() as Map<String, dynamic>)})
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching unread announcements: $e');
      return [];
    }
  }

  /// Fetch ALL active announcements with an `isRead` flag per user.
  static Future<List<Map<String, dynamic>>> getAllActiveAnnouncements() async {
    final uid = _uid;
    if (uid == null) return [];

    try {
      final announcementsSnap = await _fs
          .collection('announcements')
          .where('is_active', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .get();

      if (announcementsSnap.docs.isEmpty) return [];

      final readSnap = await _fs
          .collection('users')
          .doc(uid)
          .collection('read_announcements')
          .get();

      final readIds = readSnap.docs.map((eventId) => eventId.id).toSet();

      return announcementsSnap.docs
          .map((eventId) => {'id': eventId.id, 'isRead': readIds.contains(eventId.id), ...(eventId.data() as Map<String, dynamic>)})
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching all announcements: $e');
      return [];
    }
  }

  /// Mark a single announcement as read for the current user.
  static Future<void> markAsRead(String announcementId) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('read_announcements')
          .doc(announcementId)
          .set({
            'read_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      debugPrint('✅ Marked announcement $announcementId as read');
    } catch (e) {
      debugPrint('❌ Error marking announcement as read: $e');
    }
  }

  /// Mark multiple announcements as read in one batch.
  static Future<void> markAllAsRead(List<String> ids) async {
    final uid = _uid;
    if (uid == null || ids.isEmpty) return;

    try {
      final batch = _fs.batch();
      for (final id in ids) {
        final ref = _fs
            .collection('users')
            .doc(uid)
            .collection('read_announcements')
            .doc(id);
        batch.set(ref, {
          'read_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('✅ Marked ${ids.length} announcements as read');
    } catch (e) {
      debugPrint('❌ Error marking multiple announcements as read: $e');
    }
  }

  /// Admin only — create a new announcement.
  static Future<void> createAnnouncement({
    required String title,
    required String body,
    required bool showOnOpen,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _fs.collection('announcements').add({
        'title': title,
        'body': body,
        'show_on_open': showOnOpen,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'created_by': uid,
      });
      debugPrint('✅ Created new announcement: $title');
    } catch (e) {
      debugPrint('❌ Error creating announcement: $e');
      rethrow;
    }
  }

  /// Admin only — deactivate an announcement (soft delete).
  static Future<void> deactivateAnnouncement(String id) async {
    try {
      await _fs.collection('announcements').doc(id).update({'is_active': false});
      debugPrint('✅ Deactivated announcement: $id');
    } catch (e) {
      debugPrint('❌ Error deactivating announcement: $e');
      rethrow;
    }
  }
}





