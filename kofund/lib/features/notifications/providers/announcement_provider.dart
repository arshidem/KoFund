import 'package:flutter/material.dart';
import '../services/announcement_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _allAnnouncements = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get allAnnouncements => _allAnnouncements;
  List<Map<String, dynamic>> get unreadAnnouncements =>
      _allAnnouncements.where((a) => a['isRead'] != true).toList();

  int get unreadCount => unreadAnnouncements.length;
  bool get hasAnyAnnouncements => _allAnnouncements.isNotEmpty;
  bool get isLoading => _isLoading;

  /// Fetch all active announcements (read + unread) with their read state.
  Future<void> refreshAnnouncements() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allAnnouncements = await AnnouncementService.getAllActiveAnnouncements();
    } catch (_) {
      _allAnnouncements = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark an announcement as read locally and on Firestore.
  Future<void> markAsRead(String id) async {
    final index = _allAnnouncements.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      // Optimistic UI: mark as read locally
      _allAnnouncements[index] = {..._allAnnouncements[index], 'isRead': true};
      notifyListeners();
      await AnnouncementService.markAsRead(id);
    }
  }

  /// Mark all current unread as read.
  Future<void> markAllAsRead() async {
    final ids = unreadAnnouncements.map((a) => a['id'] as String).toList();
    // Optimistic UI: mark all as read locally
    _allAnnouncements = _allAnnouncements
        .map((a) => {...a, 'isRead': true})
        .toList();
    notifyListeners();
    await AnnouncementService.markAllAsRead(ids);
  }
}





