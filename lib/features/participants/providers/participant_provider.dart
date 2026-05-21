import 'package:flutter/material.dart';
import '../../../core/services/participant_service.dart';
import '../models/participant_model.dart';

class ParticipantProvider with ChangeNotifier {
  final ParticipantService _participantService;

  List<ParticipantModel> _eventParticipants = [];
  bool _isLoading = false;

  // 🚀 OPTIMIZATION: List cache with TTL
  final Map<String, ({List<ParticipantModel> data, DateTime timestamp})> _participantCache = {};
  final Duration _cacheTTL = const Duration(minutes: 5);

  List<ParticipantModel> get eventParticipants => _eventParticipants;
  List<ParticipantModel> get participants => _eventParticipants; // Added alias for compatibility
  bool get isLoading => _isLoading;

  ParticipantProvider({required ParticipantService participantService})
      : _participantService = participantService;

  // ✅ Load event participants
  Future<void> loadEventParticipants(String eventId, {String? communityId, bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _participantCache.containsKey(eventId)) {
      final cached = _participantCache[eventId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _eventParticipants = cached.data;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();
    
    try {
      _eventParticipants = await _participantService.getEventParticipants(eventId, communityId: communityId);
      _participantCache[eventId] = (data: _eventParticipants, timestamp: DateTime.now());
    } catch (e) {
      debugPrint('Error loading participants: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Join event
  Future<void> joinEvent(ParticipantModel participant) async {
    try {
      await _participantService.join(participant);
      _participantCache.remove(participant.eventId); // Invalidate cache
      await loadEventParticipants(participant.eventId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

Future<void> addParticipant(ParticipantModel participant) async {
  try {
    await _participantService.addParticipant(participant);
    _participantCache.remove(participant.eventId); // Invalidate cache
    await loadEventParticipants(participant.eventId, forceRefresh: true);
  } catch (e) {
    rethrow;
  }
}

/// Get participants for a event
Future<List<ParticipantModel>> getEventParticipants(String eventId, {String? communityId}) async {
  await loadEventParticipants(eventId, communityId: communityId);
  return _eventParticipants;
}

ParticipantModel? getParticipantByUserId(String eventId, String userId) {
  try {
    return _eventParticipants.firstWhere(
      (p) => p.eventId == eventId && p.userId == userId,
    );
  } catch (_) {
    return null;
  }
}

  Stream<int> streamEventParticipantCount(String eventId, {String? communityId}) {
    return _participantService.streamEventParticipantCount(eventId, communityId: communityId);
  }

  // ✅ Leave event
  Future<void> leaveEvent(String eventId, String userId, {String? communityId}) async {
    try {
      await _participantService.leave(eventId, userId, communityId: communityId);
      _participantCache.remove(eventId); // Invalidate cache
      await loadEventParticipants(eventId, forceRefresh: true, communityId: communityId);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Check if user joined (Cached)
  Future<bool> hasUserJoined(String eventId, String userId, {String? communityId}) async {
    // 🚀 OPTIMIZATION: Check cache first
    if (_participantCache.containsKey(eventId)) {
      final cached = _participantCache[eventId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data.any((p) => p.userId == userId && p.status == 'joined');
      }
    }
    return await _participantService.hasUserJoinedEvent(eventId, userId, communityId: communityId);
  }

  // ✅ Get participant count (Cached)
  Future<int> getParticipantCount(String eventId, {String? communityId}) async {
    // 🚀 OPTIMIZATION: Check cache first
    if (_participantCache.containsKey(eventId)) {
      final cached = _participantCache[eventId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data.length;
      }
    }
    return await _participantService.getParticipantCount(eventId, communityId: communityId);
  }

  // ✅ Update payment status
  Future<void> updatePaymentStatus(String participantId, double amount, bool hasPaid) async {
    await _participantService.updatePaymentStatus(participantId, amount, hasPaid);
    // Note: We don't have eventId here easily, so we might need to clear all caches or pass it in.
    _participantCache.clear(); 
    notifyListeners();
  }

  // ✅ Stream event participants for real-time updates
  Stream<List<ParticipantModel>> streamEventParticipants(String eventId, {String? communityId}) {
    return _participantService.streamParticipants(eventId, communityId: communityId);
  }

  // ✅ Search participants by name
  List<ParticipantModel> searchParticipants(String query) {
    if (query.isEmpty) return _eventParticipants;
    
    return _eventParticipants.where((participant) =>
      participant.userName.toLowerCase().contains(query.toLowerCase()) ||
      participant.userEmail.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  // ✅ Filter participants by payment status
  List<ParticipantModel> filterParticipantsByPayment(List<ParticipantModel> participants, String filter) {
    switch (filter) {
      case 'paid':
        return participants.where((p) => p.hasPaidContribution).toList();
      case 'pending':
        return participants.where((p) => !p.hasPaidContribution).toList();
      default:
        return participants;
    }
  }
}





