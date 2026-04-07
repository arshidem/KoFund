import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/participant_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../../core/services/program_service.dart';
import 'dart:async';
import '../models/program_model.dart';
import '../../participants/models/participant_model.dart';
import '../../contributions/models/contribution_model.dart';

class ProgramProvider with ChangeNotifier {
  final ProgramService _programService;
  final ParticipantService _participantService;
  final ContributionService _contributionService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ProgramModel> _programs = [];
  List<ParticipantModel> _myParticipations = [];
  
  bool _isLoading = false;

  String? _error;
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
    _isLoading = false;
    _error = null;
    notifyListeners();
    debugPrint('🔄 ProgramProvider: User data cleared');
  }

  Future<void> refreshProgramData(String programId) async {
    try {
      debugPrint('🔄 ProgramProvider: Refreshing program data for $programId');
      final index = _programs.indexWhere((p) => p.programId == programId);
      if (index != -1) {
        _programs.removeAt(index);
      }
      notifyListeners();
      await _programService.getProgramById(programId);
      debugPrint('✅ ProgramProvider: Program data refreshed for $programId');
    } catch (e) {
      debugPrint('❌ ProgramProvider: Error refreshing program data: $e');
      rethrow;
    }
  }

  void clearAllData() {
    clearUserData();
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

  // ✅ OPTIMIZED: Stream with monthly contributions - BATCH FETCHING
  Stream<List<ParticipantModel>> streamProgramParticipantsWithMonthlyContributions(
    String programId, 
    String monthId
  ) {
    return _participantService.streamProgramParticipants(programId).asyncMap((participants) async {
      if (participants.isEmpty) return [];
      
      try {
        // 1. Fetch program document once
        final programDoc = await _firestore.collection('programs').doc(programId).get();
        final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
        
        // 2. Fetch all monthly contributions for this program-month once
        final monthlyContributions = await _contributionService.getMonthlyContributionsForProgram(
          programId,
          monthId,
        );
        
        // 3. Map contributions by userId for O(1) lookup
        final Map<String, double> userPaidMap = {};
        for (final contribution in monthlyContributions) {
          userPaidMap[contribution.userId] = (userPaidMap[contribution.userId] ?? 0.0) + contribution.amount;
        }
        
        // 4. Update participants using the map
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

  // ✅ OPTIMIZED: Monthly financial summary - REUSES PARTICIPANT STREAM
  Stream<Map<String, dynamic>> streamProgramMonthlyFinancialSummary(
    String programId, 
    String monthId
  ) {
    return streamProgramParticipantsWithMonthlyContributions(programId, monthId)
        .asyncMap((participants) async {
      if (participants.isEmpty) {
        return {
          'totalParticipants': 0,
          'paidParticipants': 0,
          'pendingParticipants': 0,
          'totalCollected': 0.0,
          'totalExpected': 0.0,
          'collectionRate': 0.0,
          'monthId': monthId,
        };
      }

      // 1. Fetch program once for suggested contribution
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
      
      // 2. Calculate summary from already optimized participants list
      int paidParticipants = 0;
      double totalCollected = 0.0;
      
      for (final participant in participants) {
        totalCollected += participant.contributionPaid ?? 0.0;
        if (participant.hasPaidContribution) {
          paidParticipants++;
        }
      }
      
      final totalExpected = suggestedContribution * participants.length;
      final collectionRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0;

      return {
        'totalParticipants': participants.length,
        'paidParticipants': paidParticipants,
        'pendingParticipants': participants.length - paidParticipants,
        'totalCollected': totalCollected,
        'totalExpected': totalExpected,
        'collectionRate': collectionRate,
        'suggestedContribution': suggestedContribution,
        'monthId': monthId,
      };
    });
  }

  // ✅ OPTIMIZED: Stream that includes contribution data - BATCH FETCHING
  Stream<List<ParticipantModel>> streamProgramParticipantsWithContributions(String programId) {
    return _participantService.streamProgramParticipants(programId).asyncMap((participants) async {
      if (participants.isEmpty) return [];
      
      try {
        // 1. Fetch program once
        final programDoc = await _firestore.collection('programs').doc(programId).get();
        final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
        
        // 2. Fetch ALL contributions for this program once
        final allContributions = await _contributionService.getProgramContributions(programId);
        
        // 3. Map contributions by userId
        final Map<String, double> userPaidMap = {};
        for (final contribution in allContributions) {
          userPaidMap[contribution.userId] = (userPaidMap[contribution.userId] ?? 0.0) + contribution.amount;
        }
        
        // 4. Update participants
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

  // ✅ OPTIMIZED: Get program participants with real-time contribution data
  Future<List<ParticipantModel>> getProgramParticipantsWithContributions(String programId) async {
    try {
      final participants = await _participantService.getProgramParticipants(programId);
      if (participants.isEmpty) return [];

      // 1. Fetch program once
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();

      // 2. Fetch all contributions once
      final allContributions = await _contributionService.getProgramContributions(programId);

      // 3. Map by userId
      final Map<String, double> userPaidMap = {};
      for (final contribution in allContributions) {
        userPaidMap[contribution.userId] = (userPaidMap[contribution.userId] ?? 0.0) + contribution.amount;
      }

      // 4. Update participants
      return participants.map((participant) {
        final amountPaid = userPaidMap[participant.userId] ?? 0.0;
        final hasPaid = suggestedContribution > 0 ? amountPaid >= suggestedContribution : true;
        return participant.copyWith(
          contributionPaid: amountPaid,
          hasPaidContribution: hasPaid,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error in optimized participants future: $e');
      return [];
    }
  }

  // ✅ OPTIMIZED: Get program financial summary
  Future<Map<String, dynamic>> getProgramFinancialSummary(String programId) async {
    try {
      final participants = await getProgramParticipantsWithContributions(programId);
      
      // 1. Fetch program once for suggested contribution calculation
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
      
      int paidParticipants = 0;
      double totalCollected = 0.0;
      
      for (final participant in participants) {
        final contributionPaid = participant.contributionPaid ?? 0.0;
        totalCollected += contributionPaid;
        if (participant.hasPaidContribution) {
          paidParticipants++;
        }
      }
      
      final totalExpected = suggestedContribution * participants.length;
      final collectionRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0;

      return {
        'totalParticipants': participants.length,
        'paidParticipants': paidParticipants,
        'pendingParticipants': participants.length - paidParticipants,
        'totalCollected': totalCollected,
        'totalExpected': totalExpected,
        'collectionRate': collectionRate,
        'suggestedContribution': suggestedContribution,
      };
    } catch (e) {
      debugPrint('❌ Error getting financial summary: $e');
      return {
        'totalParticipants': 0,
        'paidParticipants': 0,
        'pendingParticipants': 0,
        'totalCollected': 0.0,
        'totalExpected': 0.0,
        'collectionRate': 0.0,
        'suggestedContribution': 0.0,
      };
    }
  }

  // ✅ OPTIMIZED: Stream program financial summary
  Stream<Map<String, dynamic>> streamProgramFinancialSummary(String programId) {
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

      // 1. Fetch program once
      final programDoc = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (programDoc.data()?['suggestedContribution'] ?? 0).toDouble();
      
      int paidParticipants = 0;
      double totalCollected = 0.0;
      
      for (final participant in participants) {
        totalCollected += participant.contributionPaid ?? 0.0;
        if (participant.hasPaidContribution) {
          paidParticipants++;
        }
      }
      
      final totalExpected = suggestedContribution * participants.length;
      final collectionRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0;

      return {
        'totalParticipants': participants.length,
        'paidParticipants': paidParticipants,
        'pendingParticipants': participants.length - paidParticipants,
        'totalCollected': totalCollected,
        'totalExpected': totalExpected,
        'collectionRate': collectionRate,
        'suggestedContribution': suggestedContribution,
      };
    });
  }

  Future<void> createProgram(ProgramModel program) async {
    try {
      await _programService.createProgram(program);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadCommunityPrograms(String communityId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _programs = await _programService.getProgramsByCommunity(communityId);
      for (final program in _programs) {
        try {
          await program.syncComputedStatusToFirestore();
        } catch (e) {
          debugPrint('❌ Error syncing status for program ${program.programId}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading programs: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
      debugPrint('✅ Program status sync completed for ${_programs.length} programs');
    } catch (e) {
      debugPrint('❌ Error in syncAllProgramsStatus: $e');
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
        contributionPaid: program.suggestedContribution != null ? 0 : null,
        hasPaidContribution: program.suggestedContribution == null || program.isMonthlyPaymentProgram,
      );

      await _participantService.joinProgram(participant);
      await loadMyParticipations(userId, communityId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveProgram(String programId, String userId) async {
    try {
      await _participantService.leaveProgram(programId, userId);
      final program = await _programService.getProgramById(programId);
      if (program != null) {
        await loadMyParticipations(userId, program.communityId);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addContributionReminderDate(String programId, DateTime date) async {
    try {
      await _programService.addContributionReminderDate(programId, date);
      final index = _programs.indexWhere((p) => p.programId == programId);
      if (index != -1) {
        final program = _programs[index];
        final updatedDates = List<DateTime>.from(program.contributionReminderDates)
          ..add(date)
          ..sort();
        
        _programs[index] = program.copyWith(
          contributionReminderDates: updatedDates,
          enableAutoReminders: true,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error adding reminder date: $e');
      rethrow;
    }
  }
  
  Future<void> removeContributionReminderDate(String programId, DateTime date) async {
    try {
      await _programService.removeContributionReminderDate(programId, date);
      final index = _programs.indexWhere((p) => p.programId == programId);
      if (index != -1) {
        final program = _programs[index];
        final updatedDates = List<DateTime>.from(program.contributionReminderDates)
          ..removeWhere((d) => d.isAtSameMomentAs(date));
        
        _programs[index] = program.copyWith(
          contributionReminderDates: updatedDates,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing reminder date: $e');
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
      final index = _programs.indexWhere((p) => p.programId == programId);
      if (index != -1) {
        final program = _programs[index];
        _programs[index] = program.copyWith(
          enableAutoReminders: enableAutoReminders ?? program.enableAutoReminders,
          reminderDaysBefore: reminderDaysBefore ?? program.reminderDaysBefore,
          reminderFrequency: reminderFrequency ?? program.reminderFrequency,
          firstPaymentDueDate: firstPaymentDueDate ?? program.firstPaymentDueDate,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating reminder settings: $e');
      rethrow;
    }
  }
  
  Future<void> clearAllReminderDates(String programId) async {
    try {
      await _programService.clearAllReminderDates(programId);
      final index = _programs.indexWhere((p) => p.programId == programId);
      if (index != -1) {
        final program = _programs[index];
        _programs[index] = program.copyWith(
          contributionReminderDates: [],
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing reminder dates: $e');
      rethrow;
    }
  }

  Future<void> sendContributionReminder(String programId) async {
    try {
      await _programService.sendContributionReminder(programId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error sending reminder: $e');
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
      debugPrint('❌ Error updating reminder settings: $e');
      rethrow;
    }
  }

  Future<List<ProgramModel>> getProgramsWithUpcomingReminders(String communityId) async {
    try {
      return await _programService.getProgramsWithUpcomingReminders(communityId);
    } catch (e) {
      debugPrint('❌ Error getting upcoming reminders: $e');
      return [];
    }
  }

  Stream<List<ProgramModel>> streamProgramsWithUpcomingReminders(String communityId) {
    return _firestore
        .collection('programs')
        .where('communityId', isEqualTo: communityId)
        .where('enableAutoReminders', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .where('nextReminderDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('nextReminderDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<Map<String, dynamic>> getReminderStatus(String programId) async {
    try {
      final program = await _programService.getProgramById(programId);
      if (program == null) {
        return {
          'hasReminders': false,
          'nextReminder': null,
          'participantsToNotify': 0,
          'status': 'no_program',
        };
      }
      final unpaidParticipants = await _programService.getParticipantsWithUnpaidContributions(programId);
      return {
        'hasReminders': program.enableAutoReminders,
        'nextReminder': program.nextReminderDate,
        'participantsToNotify': unpaidParticipants.length,
        'totalParticipants': unpaidParticipants.length,
        'reminderFrequency': program.reminderFrequency,
        'daysBefore': program.reminderDaysBefore,
        'firstPaymentDue': program.firstPaymentDueDate,
        'status': program.enableAutoReminders ? 'active' : 'disabled',
      };
    } catch (e) {
      debugPrint('❌ Error getting reminder status: $e');
      return {
        'hasReminders': false,
        'nextReminder': null,
        'participantsToNotify': 0,
        'status': 'error',
      };
    }
  }

  Future<ProgramModel?> getMonthlyPaymentProgram(String communityId) async {
    try {
      final programs = await _programService.getProgramsByCommunity(communityId);
      return programs.firstWhere(
        (program) => program.isMonthlyPaymentProgram,
        orElse: () => ProgramModel(
          programId: '',
          communityId: communityId,
          title: '',
          description: '',
          programDate: DateTime.now(),
          location: '',
          maxParticipants: 0,
          participantType: 'fixed',
          status: 'active',
          createdBy: '',
          createdAt: Timestamp.now(),
          programType: 'monthly',
          isMonthlyPaymentProgram: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error getting monthly payment program: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getMonthlyProgramFinancialStats(String communityId) async {
    try {
      final monthlyProgram = await getMonthlyPaymentProgram(communityId);
      if (monthlyProgram == null || monthlyProgram.programId.isEmpty) {
        return {
          'hasMonthlyProgram': false,
          'totalCollected': 0.0,
          'totalMembers': 0,
          'paidMembers': 0,
          'balance': 0.0,
        };
      }
      final financialSummary = await getProgramFinancialSummary(monthlyProgram.programId);
      return {
        'hasMonthlyProgram': true,
        'programId': monthlyProgram.programId,
        'programTitle': monthlyProgram.title,
        'totalCollected': financialSummary['totalCollected'] ?? 0.0,
        'totalMembers': financialSummary['totalParticipants'] ?? 0,
        'paidMembers': financialSummary['paidParticipants'] ?? 0,
        'balance': financialSummary['totalCollected'] ?? 0.0,
        'suggestedContribution': monthlyProgram.suggestedContribution ?? 0.0,
        'collectionRate': financialSummary['collectionRate'] ?? 0.0,
      };
    } catch (e) {
      debugPrint('❌ Error getting monthly program stats: $e');
      return {
        'hasMonthlyProgram': false,
        'totalCollected': 0.0,
        'totalMembers': 0,
        'paidMembers': 0,
        'balance': 0.0,
      };
    }
  }

  Stream<Map<String, dynamic>> streamMonthlyProgramFinancialStats(String communityId) {
    return _programService.streamProgramsByCommunity(communityId).asyncMap((programs) async {
      final monthlyProgram = programs.firstWhere(
        (program) => program.isMonthlyPaymentProgram,
        orElse: () => ProgramModel(
          programId: '',
          communityId: communityId,
          title: '',
          description: '',
          programDate: DateTime.now(),
          location: '',
          maxParticipants: 0,
          participantType: 'fixed',
          status: 'active',
          createdBy: '',
          createdAt: Timestamp.now(),
          programType: 'monthly',
          isMonthlyPaymentProgram: false,
        ),
      );

      if (monthlyProgram.programId.isEmpty) {
        return {
          'hasMonthlyProgram': false,
          'totalCollected': 0.0,
          'totalMembers': 0,
          'paidMembers': 0,
          'balance': 0.0,
        };
      }
      final financialSummary = await getProgramFinancialSummary(monthlyProgram.programId);
      return {
        'hasMonthlyProgram': true,
        'programId': monthlyProgram.programId,
        'programTitle': monthlyProgram.title,
        'totalCollected': financialSummary['totalCollected'] ?? 0.0,
        'totalMembers': financialSummary['totalParticipants'] ?? 0,
        'paidMembers': financialSummary['paidParticipants'] ?? 0,
        'balance': financialSummary['totalCollected'] ?? 0.0,
        'suggestedContribution': monthlyProgram.suggestedContribution ?? 0.0,
        'collectionRate': financialSummary['collectionRate'] ?? 0.0,
      };
    });
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

  StreamSubscription? _participationSub;

  void watchUserParticipation(String communityId, String userId) {
    _participationSub?.cancel();
    _participationSub = FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('participations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _myParticipations = snapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  Stream<bool> streamUserJoinedStatus(String programId, String userId) {
    return _firestore
        .collection('communities')
        .doc(_getCommunityIdFromProgram(programId))
        .collection('participations')
        .where('programId', isEqualTo: programId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'joined')
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  String _getCommunityIdFromProgram(String programId) {
    final program = _programs.firstWhere(
      (p) => p.programId == programId,
      orElse: () => ProgramModel(
        programId: '',
        communityId: '',
        title: '',
        description: '',
        programDate: DateTime.now(),
        location: '',
        maxParticipants: 0,
        participantType: 'fixed',
        status: 'active',
        createdBy: '',
        createdAt: Timestamp.now(),
        programType: 'general',
        isMonthlyPaymentProgram: false,
      ),
    );
    return program.communityId;
  }

  final Map<String, StreamSubscription> _programJoinSubscriptions = {};

  void watchProgramJoinStatus(String programId, String userId, String communityId) {
    _programJoinSubscriptions[programId]?.cancel();
    _programJoinSubscriptions[programId] = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('participations')
        .where('programId', isEqualTo: programId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      final hasJoined = snapshot.docs.isNotEmpty && snapshot.docs.first['status'] == 'joined';
      if (hasJoined) {
        final participant = ParticipantModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        if (!_myParticipations.any((p) => p.participantId == participant.participantId)) {
          _myParticipations.add(participant);
        }
      } else {
        _myParticipations.removeWhere((p) => p.programId == programId && p.userId == userId);
      }
      notifyListeners();
    });
  }

  void cancelProgramWatch(String programId) {
    _programJoinSubscriptions[programId]?.cancel();
    _programJoinSubscriptions.remove(programId);
  }

  Future<int> getProgramParticipantCount(String programId) async {
    try {
      return await _participantService.getProgramParticipantCount(programId);
    } catch (e) {
      debugPrint('Error getting participant count: $e');
      return 0;
    }
  }

  Stream<int> streamProgramParticipantCount(String programId) {
    return _participantService.streamProgramParticipantCount(programId);
  }

  Future<ProgramModel?> getProgramWithLiveCount(String programId) async {
    try {
      final program = await _programService.getProgramById(programId);
      if (program != null) {
        final participantCount = await getProgramParticipantCount(programId);
        return program.copyWith(currentParticipants: participantCount);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting program with live count: $e');
      return null;
    }
  }

  Stream<ProgramModel?> streamProgramWithLiveCount(String programId) {
    return _programService.getProgramStreamById(programId).asyncMap((program) async {
      if (program != null) {
        final participantCount = await getProgramParticipantCount(programId);
        return program.copyWith(currentParticipants: participantCount);
      }
      return null;
    });
  }

  Stream<List<ProgramModel>> streamCommunityProgramsWithLiveCounts(String communityId) {
    return _programService.streamProgramsByCommunity(communityId).asyncMap((programs) async {
      final List<ProgramModel> updatedPrograms = [];
      for (final program in programs) {
        try {
          final participantCount = await getProgramParticipantCount(program.programId);
          updatedPrograms.add(program.copyWith(currentParticipants: participantCount));
        } catch (e) {
          updatedPrograms.add(program);
        }
      }
      return updatedPrograms;
    });
  }

  Stream<List<ProgramModel>> streamProgramsWithFinancialGoals(String communityId) {
    return _programService.streamProgramsWithFinancialGoals(communityId).asyncMap((programs) async {
      final List<ProgramModel> updatedPrograms = [];
      for (final program in programs) {
        try {
          final participantCount = await getProgramParticipantCount(program.programId);
          updatedPrograms.add(program.copyWith(currentParticipants: participantCount));
        } catch (e) {
          updatedPrograms.add(program);
        }
      }
      return updatedPrograms;
    });
  }

  Future<void> addProgramContribution(ContributionModel contribution) async {
    try {
      await _contributionService.addContribution(contribution);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ContributionModel>> getProgramContributions(String programId) async {
    try {
      return await _contributionService.getProgramContributions(programId);
    } catch (e) {
      debugPrint('Error loading contributions: $e');
      return [];
    }
  }

  Future<List<ProgramModel>> getOngoingPrograms(String communityId) async {
    final programs = await _programService.getActiveProgramsByCommunity(communityId);
    return programs.where((p) => p.isMonthlyPaymentProgram == false).toList();
  }

  Future<double> getProgramTotalContributions(String programId) async {
    try {
      return await _contributionService.getProgramTotalContributions(programId);
    } catch (e) {
      debugPrint('Error calculating total contributions: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getProgramFinancialProgress(String programId) async {
    try {
      final program = await _programService.getProgramById(programId);
      if (program == null) {
        return {
          'totalCollected': 0,
          'progressPercentage': 0,
          'estimatedTotal': 0,
          'hasFinancialGoals': false,
        };
      }
      final totalCollected = await getProgramTotalContributions(programId);
      final participantCount = await getProgramParticipantCount(programId);
      double progressPercentage = 0;
      double estimatedTotal = 0;
      if (program.totalProgramAmount != null) {
        estimatedTotal = program.totalProgramAmount!;
        progressPercentage = estimatedTotal > 0 ? (totalCollected / estimatedTotal) * 100 : 0;
      } else if (program.suggestedContribution != null && program.suggestedContribution! > 0) {
        estimatedTotal = program.suggestedContribution! * participantCount;
        progressPercentage = estimatedTotal > 0 ? (totalCollected / estimatedTotal) * 100 : 0;
      }
      return {
        'totalCollected': totalCollected,
        'progressPercentage': progressPercentage,
        'estimatedTotal': estimatedTotal,
        'hasFinancialGoals': program.hasFinancialGoals,
        'participantCount': participantCount,
        'suggestedContribution': program.suggestedContribution,
        'totalProgramAmount': program.totalProgramAmount,
      };
    } catch (e) {
      debugPrint('Error calculating financial progress: $e');
      return {
        'totalCollected': 0,
        'progressPercentage': 0,
        'estimatedTotal': 0,
        'hasFinancialGoals': false,
        'participantCount': 0,
        'suggestedContribution': null,
        'totalProgramAmount': null,
      };
    }
  }

  Stream<List<ParticipantModel>> streamUserParticipations(String userId, String communityId) {
    return _participantService.streamUserProgramParticipations(userId, communityId);
  }

  Stream<double> streamProgramTotalContributions(String programId) {
    return _contributionService.streamProgramTotalContributions(programId);
  }

  Stream<ProgramModel?> getProgramById(String programId) {
    return _programService.getProgramStreamById(programId);
  }

  Future<List<ParticipantModel>> getProgramParticipants(String programId) async {
    try {
      return await _participantService.getProgramParticipants(programId);
    } catch (e) {
      debugPrint('Error loading program participants: $e');
      return [];
    }
  }

  Stream<List<ParticipantModel>> streamProgramParticipants(String programId) {
    return _participantService.streamProgramParticipants(programId);
  }

  Future<void> updateProgramStatus(String programId, String status) async {
    try {
      await _programService.updateProgramStatus(programId, status);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProgram(ProgramModel program) async {
    try {
      await _programService.updateProgramModel(program);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProgramFinancials({
    required String programId,
    double? suggestedContribution,
    double? totalProgramAmount,
  }) async {
    try {
      await _programService.updateProgramFinancials(
        programId,
        suggestedContribution: suggestedContribution,
        totalProgramAmount: totalProgramAmount,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProgram(String programId) async {
    try {
      await _programService.deleteProgram(programId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<ParticipantModel?> getParticipantByProgramAndUser(String programId, String userId) async {
    try {
      return await _participantService.getParticipantByProgramAndUser(programId, userId);
    } catch (e) {
      debugPrint('Error getting participant: $e');
      return null;
    }
  }

  Future<void> updateParticipantPaymentStatus(
    String participantId, 
    double amountPaid, 
    bool hasFullyPaid
  ) async {
    try {
      await _participantService.updatePaymentStatus(participantId, amountPaid, hasFullyPaid);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProgramModel>> getProgramsWithFinancialGoals(String communityId) async {
    try {
      final programs = await _programService.getProgramsWithFinancialGoals(communityId);
      final List<ProgramModel> updatedPrograms = [];
      for (final program in programs) {
        try {
          final participantCount = await getProgramParticipantCount(program.programId);
          updatedPrograms.add(program.copyWith(currentParticipants: participantCount));
        } catch (e) {
          updatedPrograms.add(program);
        }
      }
      return updatedPrograms;
    } catch (e) {
      debugPrint('Error loading programs with financial goals: $e');
      return [];
    }
  }

  Future<void> refreshCommunityData(String communityId, String userId) async {
    await Future.wait([
      loadCommunityPrograms(communityId),
      loadMyParticipations(userId, communityId),
    ]);
  }

  Future<List<Map<String, dynamic>>> getParticipantsWithMonthlyStatus(
    String programId, 
    String monthId,
    String communityId
  ) async {
    try {
      final contributionService = ContributionService();
      final usersSnapshot = await _firestore
          .collection('users')
          .where('communityId', isEqualTo: communityId)
          .where('isApproved', isEqualTo: true)
          .get();
      final paymentStatus = await contributionService.getMonthlyPaymentStatus(programId, monthId);
      final List<Map<String, dynamic>> result = [];
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;
        result.add({
          'userId': userId,
          'userName': userData['displayName'] ?? 'Unknown User',
          'userEmail': userData['email'] ?? '',
          'userAvatar': userData['photoURL'] ?? '',
          'hasPaidForMonth': paymentStatus[userId] ?? false,
        });
      }
      result.sort((a, b) => (a['userName'] as String).compareTo(b['userName'] as String));
      return result;
    } catch (e) {
      debugPrint('❌ Error getting participants with monthly status: $e');
      return [];
    }
  }

  void clearData() {
    _programs.clear();
    _myParticipations.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _participationSub?.cancel();
    super.dispose();
  }
}

class ProgramWithJoinStatus {
  final ProgramModel program;
  final bool hasJoined;
  final ParticipantModel? participant;

  ProgramWithJoinStatus({
    required this.program,
    required this.hasJoined,
    this.participant,
  });
}
