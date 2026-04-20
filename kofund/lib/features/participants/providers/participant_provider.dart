import 'package:flutter/material.dart';
import '../../../core/services/participant_service.dart';
import '../models/participant_model.dart';

class ParticipantProvider with ChangeNotifier {
  final ParticipantService _participantService;

  List<ParticipantModel> _programParticipants = [];
  bool _isLoading = false;

  // 🚀 OPTIMIZATION: List cache with TTL
  final Map<String, ({List<ParticipantModel> data, DateTime timestamp})> _participantCache = {};
  final Duration _cacheTTL = const Duration(minutes: 5);

  List<ParticipantModel> get programParticipants => _programParticipants;
  bool get isLoading => _isLoading;

  ParticipantProvider({required ParticipantService participantService})
      : _participantService = participantService;

  // ✅ Load program participants
  Future<void> loadProgramParticipants(String programId, {bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _participantCache.containsKey(programId)) {
      final cached = _participantCache[programId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _programParticipants = cached.data;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();
    
    try {
      _programParticipants = await _participantService.getProgramParticipants(programId);
      _participantCache[programId] = (data: _programParticipants, timestamp: DateTime.now());
    } catch (e) {
      debugPrint('Error loading participants: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Join program
  Future<void> joinProgram(ParticipantModel participant) async {
    try {
      await _participantService.joinProgram(participant);
      _participantCache.remove(participant.programId); // Invalidate cache
      await loadProgramParticipants(participant.programId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

Future<void> addParticipant(ParticipantModel participant) async {
  try {
    await _participantService.addParticipant(participant);
    _participantCache.remove(participant.programId); // Invalidate cache
    await loadProgramParticipants(participant.programId, forceRefresh: true);
  } catch (e) {
    rethrow;
  }
}

/// Get participants for a program
Future<List<ParticipantModel>> getProgramParticipants(String programId) async {
  await loadProgramParticipants(programId);
  return _programParticipants;
}

ParticipantModel? getParticipantByUserId(String programId, String userId) {
  try {
    return _programParticipants.firstWhere(
      (p) => p.programId == programId && p.userId == userId,
    );
  } catch (_) {
    return null;
  }
}

Stream<int> streamProgramParticipantCount(String programId) {
  return _participantService.streamProgramParticipantCount(programId);
}

  // ✅ Leave program
  Future<void> leaveProgram(String programId, String userId) async {
    try {
      await _participantService.leaveProgram(programId, userId);
      _participantCache.remove(programId); // Invalidate cache
      await loadProgramParticipants(programId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Check if user joined (Cached)
  Future<bool> hasUserJoined(String programId, String userId) async {
    // 🚀 OPTIMIZATION: Check cache first
    if (_participantCache.containsKey(programId)) {
      final cached = _participantCache[programId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data.any((p) => p.userId == userId && p.status == 'joined');
      }
    }
    return await _participantService.hasUserJoinedProgram(programId, userId);
  }

  // ✅ Get participant count (Cached)
  Future<int> getParticipantCount(String programId) async {
    // 🚀 OPTIMIZATION: Check cache first
    if (_participantCache.containsKey(programId)) {
      final cached = _participantCache[programId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data.length;
      }
    }
    return await _participantService.getProgramParticipantCount(programId);
  }

  // ✅ Update payment status
  Future<void> updatePaymentStatus(String participantId, double amount, bool hasPaid) async {
    await _participantService.updatePaymentStatus(participantId, amount, hasPaid);
    // Note: We don't have programId here easily, so we might need to clear all caches or pass it in.
    _participantCache.clear(); 
    notifyListeners();
  }

  // ✅ Stream program participants for real-time updates
  Stream<List<ParticipantModel>> streamProgramParticipants(String programId) {
    return _participantService.streamProgramParticipants(programId);
  }

  // ✅ Search participants by name
  List<ParticipantModel> searchParticipants(String query) {
    if (query.isEmpty) return _programParticipants;
    
    return _programParticipants.where((participant) =>
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
