import 'package:flutter/material.dart';
import '../../../core/services/participant_service.dart';
import '../models/participant_model.dart';

class ParticipantProvider with ChangeNotifier {
  final ParticipantService _participantService;

  List<ParticipantModel> _programParticipants = [];
  bool _isLoading = false;

  List<ParticipantModel> get programParticipants => _programParticipants;
  bool get isLoading => _isLoading;

  ParticipantProvider({required ParticipantService participantService})
      : _participantService = participantService;

  // ✅ Load program participants
  Future<void> loadProgramParticipants(String programId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _programParticipants = await _participantService.getProgramParticipants(programId);
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
      await loadProgramParticipants(participant.programId);
    } catch (e) {
      rethrow;
    }
  }

Future<void> addParticipant(ParticipantModel participant) async {
  try {
    await _participantService.addParticipant(participant);
    await loadProgramParticipants(participant.programId);
  } catch (e) {
    rethrow;
  }
}
// Add to ParticipantProvider class:

/// Get participants for a program
Future<List<ParticipantModel>> getProgramParticipants(String programId) async {
  await loadProgramParticipants(programId);
  return _programParticipants;
}
// Also add this helper method if needed:
// ✅ Get participant by userId - FIXED VERSION
ParticipantModel? getParticipantByUserId(String programId, String userId) {
  try {
    return _programParticipants.firstWhere(
      (p) => p.programId == programId && p.userId == userId,
    );
  } catch (_) {
    return null;
  }
}
// Add to ParticipantProvider class
Stream<int> streamProgramParticipantCount(String programId) {
  return _participantService.streamProgramParticipantCount(programId);
}
  // ✅ Leave program
  Future<void> leaveProgram(String programId, String userId) async {
    try {
      await _participantService.leaveProgram(programId, userId);
      await loadProgramParticipants(programId);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Check if user joined
  Future<bool> hasUserJoined(String programId, String userId) async {
    return await _participantService.hasUserJoinedProgram(programId, userId);
  }

  // ✅ Get participant count
  Future<int> getParticipantCount(String programId) async {
    return await _participantService.getProgramParticipantCount(programId);
  }

  // ✅ Update payment status
  Future<void> updatePaymentStatus(String participantId, double amount, bool hasPaid) async {
    // You'll need to add this method to your ParticipantService
    // For now, we'll reload the data
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

