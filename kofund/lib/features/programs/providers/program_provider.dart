import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/participant_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../../core/services/program_service.dart';
import 'dart:async';
import '../models/program_model.dart';
import 'package:intl/intl.dart';
import '../../participants/models/participant_model.dart';

class ProgramProvider with ChangeNotifier {
  final ProgramService _programService;
  final ParticipantService _participantService;
  final ContributionService _contributionService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ProgramModel> _programs = [];
  List<ParticipantModel> _myParticipations = [];
  bool _isLoading = false;
  String? _error;

  // 🚀 OPTIMIZATION: Caches with TTL
  final Map<String, ({Map<String, dynamic> data, DateTime timestamp})> _summaryCache = {};
  final Map<String, ({List<ProgramModel> data, DateTime timestamp})> _programListCache = {};
  final Duration _cacheTTL = const Duration(minutes: 5);

  List<ProgramModel> get programs => _programs;
  String? get error => _error;
  List<ParticipantModel> get myParticipations => _myParticipations;
  bool get isLoading => _isLoading;

  ProgramProvider({
    required ProgramService programService,
    required ParticipantService participantService,
    required ContributionService contributionService,
  })  : _programService = programService,
        _participantService = participantService,
        _contributionService = contributionService;

  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearUserData() {
    _myParticipations.clear();
    _programs.clear();
    _summaryCache.clear();
    _programListCache.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
    // debugPrint('🔄 ProgramProvider: User data cleared');
  }

  void clearAllData() {
    clearUserData();
  }

  // ✅ OPTIMIZED: Get program financial summary with Cache
  Future<Map<String, dynamic>> getProgramFinancialSummary(String programId, {bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache first
    if (!forceRefresh && _summaryCache.containsKey(programId)) {
      final cached = _summaryCache[programId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data;
      }
    }

    try {
      final totalContributions = await _programService.getTotalContributions(programId);
      final totalExpenses = await _programService.getTotalExpenses(programId);
      final participantCount = await _participantService.getProgramParticipantCount(programId);
      
      final program = await _programService.getProgramById(programId);
      final suggested = program?.suggestedContribution ?? 0.0;
      
      final totalExpected = suggested * participantCount;
      final collectionRate = totalExpected > 0 ? (totalContributions / totalExpected) * 100 : 0.0;

      final summary = {
        'totalParticipants': participantCount,
        'totalCollected': totalContributions,
        'totalExpenses': totalExpenses,
        'balance': totalContributions - totalExpenses,
        'totalExpected': totalExpected,
        'collectionRate': collectionRate,
        'suggestedContribution': suggested,
      };

      // 🚀 Cache result
      _summaryCache[programId] = (data: summary, timestamp: DateTime.now());
      return summary;
    } catch (e) {
      debugPrint('❌ Error getting financial summary: $e');
      return {
        'totalParticipants': 0,
        'totalCollected': 0.0,
        'totalExpenses': 0.0,
        'balance': 0.0,
        'totalExpected': 0.0,
        'collectionRate': 0.0,
        'suggestedContribution': 0.0,
      };
    }
  }

  Future<void> loadCommunityPrograms(String communityId, {bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _programListCache.containsKey(communityId)) {
      final cached = _programListCache[communityId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _programs = cached.data;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();
    try {
      _programs = await _programService.getProgramsByCommunity(communityId);
      _programListCache[communityId] = (data: _programs, timestamp: DateTime.now());
    } catch (e) {
      debugPrint('Error loading programs: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<ProgramModel?> getProgramById(String programId) {
    // 🚀 We can still optimize by emitting the cached version first
    final controller = StreamController<ProgramModel?>();
    
    // Check cache
    final index = _programs.indexWhere((p) => p.programId == programId);
    if (index != -1) {
      controller.add(_programs[index]);
    }
    
    // Then listen to firestore for real-time updates
    _programService.getProgramStreamById(programId).listen((program) {
      if (program != null) {
        final idx = _programs.indexWhere((p) => p.programId == programId);
        if (idx != -1) {
          _programs[idx] = program;
        } else {
          _programs.add(program);
        }
        notifyListeners();
      }
      if (!controller.isClosed) {
        controller.add(program);
      }
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    }, onDone: () {
      if (!controller.isClosed) controller.close();
    });
    
    return controller.stream;
  }

  Future<void> updateProgram(ProgramModel program) async {
    try {
      await _programService.updateProgramModel(program);
      
      // ✅ Invalidate cache and reload
      _programListCache.remove(program.communityId);
      _summaryCache.remove(program.programId);
      
      await loadCommunityPrograms(program.communityId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProgram(String programId) async {
    try {
      final program = await _programService.getProgramById(programId);
      await _programService.deleteProgram(programId);
      _programs.removeWhere((p) => p.programId == programId);
      _summaryCache.remove(programId);
      if (program != null) {
        _programListCache.remove(program.communityId);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Stream for participant count
  Stream<int> streamProgramParticipantCount(String programId) {
    return _participantService.streamProgramParticipants(programId)
        .map((participants) => participants.length);
  }

  // ✅ Stream for total contributions (used in lists)
  Stream<double> streamProgramTotalContributions(String programId) {
    return _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
        .snapshots()
        .asyncMap((snapshot) async {
          // Use the faster aggregate query even for the stream mapping
          return await _contributionService.getProgramTotalContributions(programId);
        });
  }

  // 📈 NEW: Unified Progress Stream (Handles Monthly vs Global)
  Stream<Map<String, dynamic>> streamProgramProgress(String programId) {
    // 1. Get the program first (one-time)
    return streamProgramParticipantsWithContributions(programId).asyncMap((participants) async {
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      if (!programDoc.exists) {
        return {
          'collected': 0.0,
          'target': 100.0,
          'percentage': 0.0,
          'participantCount': 0,
          'isMonthly': false,
        };
      }
      
      final data = programDoc.data()!;
      final isMonthly = data['isMonthlyPaymentProgram'] ?? false;
      final suggestedContribution = (data['suggestedContribution'] ?? 0).toDouble();
      final totalProgramAmount = (data['totalProgramAmount'] ?? 0).toDouble();
      final maxParticipants = (data['maxParticipants'] ?? 0) as int;
      final isFixedParticipants = (data['participantType'] ?? 'fixed') == 'fixed';
      
      double collected = 0.0;
      double target = 0.0;
      
      if (isMonthly) {
        // --- Monthly Logic ---
        final currentMonthId = DateFormat('yyyy-MM').format(DateTime.now());
        final monthlyContributions = await _contributionService.getMonthlyContributionsForProgram(
          programId,
          currentMonthId,
        );
        
        collected = monthlyContributions.fold(0.0, (sum, c) => sum + c.amount);
        
        // Target for current month = participantCount * suggestedAmount
        // Using participants.length to count joined users
        final pCount = participants.length; 
        target = suggestedContribution * (pCount > 0 ? pCount : 1);
        
      } else {
        // --- Global Logic ---
        collected = await _programService.getTotalContributions(programId);
        
        if (totalProgramAmount > 0) {
          target = totalProgramAmount;
        } else {
          final pCount = isFixedParticipants ? maxParticipants : participants.length;
          target = suggestedContribution * (pCount > 0 ? pCount : 1);
        }
      }
      
      final percentage = target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;
      
      return {
        'collected': collected,
        'target': target,
        'percentage': percentage,
        'participantCount': participants.length,
        'isMonthly': isMonthly,
        'monthId': isMonthly ? DateFormat('yyyy-MM').format(DateTime.now()) : null,
      };
    });
  }

  // 💰 NEW: Expenses stream
  Stream<double> streamProgramExpenses(String programId) {
    return _firestore
        .collection('expenses')
        .where('programId', isEqualTo: programId)
        .snapshots()
        .map((snapshot) {
          double total = 0.0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? 'pending';
            if (status == 'approved' || status == 'completed') {
              total += (data['amount'] ?? 0).toDouble();
            }
          }
          return total;
        });
  }

  // 📊 NEW: Full Financial Summary Stream
  Stream<Map<String, dynamic>> streamProgramFinancialSummary(String programId) {
    return streamProgramParticipantsWithContributions(programId).asyncMap((participants) async {
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
      
      final allContributionsForCount = await _contributionService.getProgramContributions(programId);
      final totalContributions = participants.fold(0.0, (sum, p) => sum + (p.contributionPaid ?? 0.0));
      final totalExpenses = await _programService.getTotalExpenses(programId);
      
      int paidParticipants = 0;
      for (final p in participants) {
        if (p.hasPaidContribution) paidParticipants++;
      }
      
      final totalParticipants = participants.length;
      final totalExpected = suggestedContribution * totalParticipants;

      return {
        'totalParticipants': totalParticipants,
        'paidParticipants': paidParticipants,
        'pendingParticipants': totalParticipants - paidParticipants,
        'totalCollected': totalContributions, 
        'collected': totalContributions,      
        'totalExpected': totalExpected,
        'expenses': totalExpenses,
        'totalExpenses': totalExpenses,
        'balance': totalContributions - totalExpenses,
        'contributionCount': allContributionsForCount.length,
        'totalContributions': allContributionsForCount.length, // Alias for UI
        'participants': totalParticipants.toDouble(),
      };
    });
  }

  Future<void> createProgram(ProgramModel program, {bool sendNotification = true}) async {
    try {
      final programId = await _programService.createProgram(program, sendNotification: sendNotification);
      
      // ✅ Invalidate cache and reload to ensure the new program shows up immediately
      _programListCache.remove(program.communityId);
      await loadCommunityPrograms(program.communityId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshProgramData(String programId) async {
    try {
      // debugPrint('🔄 ProgramProvider: Refreshing program data for $programId');
      final index = _programs.indexWhere((p) => p.programId == programId);
      if (index != -1) {
        _programs.removeAt(index);
      }
      _summaryCache.remove(programId);
      notifyListeners();
      await _programService.getProgramById(programId);
      // debugPrint('✅ ProgramProvider: Program data refreshed for $programId');
    } catch (e) {
      debugPrint('❌ ProgramProvider: Error refreshing program data: $e');
      rethrow;
    }
  }

  // ✅ Stream for user joined status
  Stream<bool> streamUserJoinedStatus(String programId, String userId) {
    return _firestore
        .collection('participants') // FIXED back to participants
        .where('programId', isEqualTo: programId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // ✅ OPTIMIZED: Get participant with real-time contribution data
  Future<ParticipantModel> getParticipantWithContribution(String programId, String userId) async {
    try {
      final participant = await _participantService.getParticipant(programId, userId);
      final contributions = await _contributionService.getContributionsByUserAndProgram(
        userId: userId,
        programId: programId,
      );
      final totalPaid = contributions.fold(0.0, (sum, contribution) => sum + contribution['amount']);
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
      
      return participant.copyWith(
        contributionPaid: totalPaid,
        hasPaidContribution: suggestedContribution > 0 ? totalPaid >= suggestedContribution : false,
      );
    } catch (e) {
      debugPrint('❌ Error getting participant with contribution: $e');
      rethrow;
    }
  }

  // ✅ Stream with monthly contributions
  Stream<List<ParticipantModel>> streamProgramParticipantsWithMonthlyContributions(
    String programId, 
    String monthId
  ) {
    return _participantService.streamProgramParticipants(programId).asyncMap((participants) async {
      if (participants.isEmpty) return [];
      
      try {
        final programDoc = await _firestore.collection('programs').doc(programId).get();
        final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
        
        final monthlyContributions = await _contributionService.getMonthlyContributionsForProgram(
          programId,
          monthId,
        );
        
        final Map<String, double> userPaidMap = {};
        for (final contribution in monthlyContributions) {
          userPaidMap[contribution.userId] = (userPaidMap[contribution.userId] ?? 0.0) + contribution.amount;
        }
        
        return participants.map((participant) {
          final amountPaid = userPaidMap[participant.userId] ?? 0.0;
          final hasPaid = suggestedContribution > 0 ? amountPaid >= suggestedContribution : true;
          
          return participant.copyWith(
            contributionPaid: amountPaid,
            hasPaidContribution: hasPaid,
          );
        }).toList();
      } catch (e) {
        debugPrint('❌ Error in optimized monthly participants stream: $e');
        return participants;
      }
    });
  }

  Future<Map<String, int>> getMonthlyPaymentCounts(String programId) async {
    try {
      final contributions = await _contributionService.getProgramContributions(programId);
      final counts = <String, int>{};
      for (final contribution in contributions) {
        if (contribution.isMonthlyContribution && contribution.monthId != null) {
          counts[contribution.monthId!] = (counts[contribution.monthId!] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      debugPrint('❌ Error getting monthly payment counts: $e');
      return {};
    }
  }

  Future<void> joinProgram(
    ProgramModel program,
    String userId,
    String userName,
    String userEmail,
    String communityId,
  ) async {
    try {
      final participant = ParticipantModel(
        participantId: '', 
        programId: program.programId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        communityId: communityId,
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: 0,
        hasPaidContribution: false,
      );

      await _participantService.joinProgram(participant);
      _summaryCache.remove(program.programId);
      await loadMyParticipations(userId, communityId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadMyParticipations(String userId, String communityId) async {
    try {
      _myParticipations = await _participantService.getUserProgramParticipations(
        userId,
        communityId,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading participations: $e');
    }
  }

  bool hasUserJoined(String programId, String userId) {
    return _myParticipations.any(
      (p) => p.programId == programId && p.userId == userId && p.status == 'joined',
    );
  }

  Stream<List<ProgramModel>> streamActivePrograms(String communityId) {
    return _programService.streamActiveProgramsByCommunity(communityId);
  }

  // ✅ Stream for program financial summary
  Stream<Map<String, dynamic>> streamProgramFinancialSummaryOld(String programId) {
    // Keep this one if any older screen uses Map<String, dynamic> specifically, 
    // but the Map<String, double> version at line 303 is better for the Dashboard.
    // For now, I'll just rename it to avoid conflict or remove it if unused.
    return streamProgramParticipantsWithContributions(programId).asyncMap((participants) async {
      if (participants.isEmpty) {
        return {
          'totalParticipants': 0,
          'paidParticipants': 0,
          'pendingParticipants': 0,
          'totalCollected': 0.0,
          'totalExpected': 0.0,
          'collectionRate': 0.0,
        };
      }

      final summary = await getProgramFinancialSummary(programId);
      return summary;
    });
  }

  Stream<List<ParticipantModel>> streamProgramParticipantsWithContributions(String programId) {
    return _participantService.streamProgramParticipants(programId).asyncMap((participants) async {
      if (participants.isEmpty) return [];
      
      try {
        final programDoc = await _firestore.collection('programs').doc(programId).get();
        final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
        final allContributions = await _contributionService.getProgramContributions(programId);
        
        final Map<String, double> userPaidMap = {};
        for (final contribution in allContributions) {
          userPaidMap[contribution.userId] = (userPaidMap[contribution.userId] ?? 0.0) + contribution.amount;
        }
        
        return participants.map((participant) {
          final amountPaid = userPaidMap[participant.userId] ?? 0.0;
          final hasPaid = suggestedContribution > 0 ? amountPaid >= suggestedContribution : true;
          
          return participant.copyWith(
            contributionPaid: amountPaid,
            hasPaidContribution: hasPaid,
          );
        }).toList();
      } catch (e) {
        debugPrint('❌ Error in optimized participants stream: $e');
        return participants;
      }
    });
  }

  Future<void> leaveProgram(String programId, String userId) async {
    try {
      await _participantService.leaveProgram(programId, userId);
      final program = await _programService.getProgramById(programId);
      if (program != null) {
        await loadMyParticipations(userId, program.communityId);
      }
      _summaryCache.remove(programId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncAllProgramsStatus() async {
    try {
      for (final program in _programs) {
        try {
          await program.syncComputedStatusToFirestore();
        } catch (e) {
          debugPrint('❌ Error syncing status for program ${program.programId}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error in syncAllProgramsStatus: $e');
    }
  }

  Future<void> addContributionReminderDate(String programId, DateTime date) async {
    try {
      await _programService.addContributionReminderDate(programId, date);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> removeContributionReminderDate(String programId, DateTime date) async {
    try {
      await _programService.removeContributionReminderDate(programId, date);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> updateReminderSettings({
    required String programId,
    bool? enableAutoReminders,
    int? reminderDaysBefore,
    String? reminderFrequency,
    DateTime? firstPaymentDueDate,
  }) async {
    try {
      await _programService.updateReminderSettings(
        programId: programId,
        enableAutoReminders: enableAutoReminders,
        reminderDaysBefore: reminderDaysBefore,
        reminderFrequency: reminderFrequency,
        firstPaymentDueDate: firstPaymentDueDate,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> clearAllReminderDates(String programId) async {
    try {
      await _programService.clearAllReminderDates(programId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendContributionReminder(String programId) async {
    try {
      await _programService.sendContributionReminder(programId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProgramReminderSettings({
    required String programId,
    bool? enableAutoReminders,
    int? reminderDaysBefore,
    String? reminderFrequency,
    List<DateTime>? contributionReminderDates,
    DateTime? firstPaymentDueDate,
    DateTime? nextReminderDate,
  }) async {
    try {
      await _programService.updateProgramReminderSettings(
        programId: programId,
        enableAutoReminders: enableAutoReminders,
        reminderDaysBefore: reminderDaysBefore,
        reminderFrequency: reminderFrequency,
        contributionReminderDates: contributionReminderDates,
        firstPaymentDueDate: firstPaymentDueDate,
        nextReminderDate: nextReminderDate,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getReminderStatus(String programId) async {
    try {
      final program = await _programService.getProgramById(programId);
      if (program == null) return {'hasReminders': false};
      final unpaidParticipants = await _programService.getParticipantsWithUnpaidContributions(programId);
      return {
        'hasReminders': program.enableAutoReminders,
        'nextReminder': program.nextReminderDate,
        'participantsToNotify': unpaidParticipants.length,
        'status': program.enableAutoReminders ? 'active' : 'disabled',
      };
    } catch (e) {
      return {'hasReminders': false};
    }
  }

  Future<ProgramModel?> getMonthlyPaymentProgram(String communityId) async {
    try {
      final programs = await _programService.getProgramsByCommunity(communityId);
      return programs.firstWhere((p) => p.isMonthlyPaymentProgram, orElse: () => throw 'Not found');
    } catch (e) {
      return null;
    }
  }

  StreamSubscription? _participationSub;
  void watchUserParticipation(String communityId, String userId) {
    _participationSub?.cancel();
    _participationSub = _firestore
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .listen((snapshot) {
      _myParticipations = snapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  Stream<Map<String, dynamic>> streamProgramMonthlyFinancialSummary(String programId, String monthId) {
    return streamProgramParticipantsWithMonthlyContributions(programId, monthId)
        .asyncMap((participants) async {
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
      
      final monthlyContributions = await _contributionService.getMonthlyContributionsForProgram(programId, monthId);
      
      int paidParticipants = 0;
      double totalCollected = 0.0;
      for (final p in participants) {
        totalCollected += p.contributionPaid ?? 0.0;
        if (p.hasPaidContribution) paidParticipants++;
      }
      
      final totalParticipants = participants.length;
      final totalExpected = suggestedContribution * totalParticipants;
      
      return {
        'totalParticipants': totalParticipants,
        'paidParticipants': paidParticipants,
        'pendingParticipants': totalParticipants - paidParticipants,
        'totalCollected': totalCollected,
        'collected': totalCollected,
        'totalExpected': totalExpected,
        'contributionCount': monthlyContributions.length,
        'totalContributions': monthlyContributions.length,
        'monthId': monthId,
        'expenses': 0.0, 
        'balance': totalCollected,
      };
    });
  }

  void clearCache() {
    _summaryCache.clear();
    _programListCache.clear();
  }
}
