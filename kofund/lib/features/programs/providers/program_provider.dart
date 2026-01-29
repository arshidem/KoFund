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
  // In lib/features/programs/providers/program_provider.dart
void clearUserData() {
  // Clear any user-specific caches
  _myParticipations.clear();
  _programs.clear(); // Clear programs cache if needed
  _isLoading = false;
  _error = null;
  notifyListeners();
  print('🔄 ProgramProvider: User data cleared');
}
// Add this to your ProgramProvider class
Future<void> refreshProgramData(String programId) async {
  try {
    print('🔄 ProgramProvider: Refreshing program data for $programId');
    
    // Clear this specific program from cache to force re-fetch
    final index = _programs.indexWhere((p) => p.programId == programId);
    if (index != -1) {
      _programs.removeAt(index);
    }
    
    // Force a re-fetch by triggering notifyListeners
    // This will cause streams to re-fetch from Firestore
    notifyListeners();
    
    // Optional: Force re-fetch the program
    await _programService.getProgramById(programId);
    
    print('✅ ProgramProvider: Program data refreshed for $programId');
  } catch (e) {
    print('❌ ProgramProvider: Error refreshing program data: $e');
    rethrow;
  }
}
// Add this for compatibility
void clearAllData() {
  clearUserData();
}
  // ✅ ADDED: Method to get participant with real-time contribution data
  Future<ParticipantModel> getParticipantWithContribution(String programId, String userId) async {
    try {
      // Get participant data
      final participant = await _participantService.getParticipant(programId, userId);
      
      // Get contribution data for this user in this program
      final contributions = await _contributionService.getContributionsByUserAndProgram(
        userId: userId,
        programId: programId,
      );
      
      // Calculate total paid amount
      final totalPaid = contributions.fold(0.0, (sum, contribution) => sum + contribution['amount']);
      
      // Get program suggested contribution
      final program = await _firestore.collection('programs').doc(programId).get();
      final suggestedContribution = (program.data()?['suggestedContribution'] ?? 0).toDouble();
      
      // Update participant with real-time contribution data
      return participant.copyWith(
        contributionPaid: totalPaid,
        hasPaidContribution: suggestedContribution > 0 ? totalPaid >= suggestedContribution : false,
      );
    } catch (e) {
      print('❌ Error getting participant with contribution: $e');
      rethrow;
    }
  }
// ✅ Stream with monthly contributions - CORRECTED VERSION
// ✅ STREAM WITH MONTHLY CONTRIBUTIONS - CORRECTED with proper parameters
Stream<List<ParticipantModel>> streamProgramParticipantsWithMonthlyContributions(
  String programId, 
  String monthId
) {
  return _participantService.streamProgramParticipants(programId).asyncMap((participants) async {
    final updatedParticipants = <ParticipantModel>[];
    
    for (final participant in participants) {
      try {
        // ✅ CORRECT: Pass all 3 required parameters
        final hasPaid = await _contributionService.hasUserPaidForMonth(
          participant.userId,    // userId
          programId,             // programId  
          monthId,               // monthId
        );
        
        // Get monthly contributions for this user
        final monthlyContributions = await _contributionService.getMonthlyContributionsForProgram(
          programId,
          monthId,
        );
        
        final userMonthlyContributions = monthlyContributions
            .where((c) => c.userId == participant.userId)
            .toList();
        
        final monthlyPaid = userMonthlyContributions.fold(
          0.0, (sum, c) => sum + c.amount
        );
        
        final program = await _firestore.collection('programs').doc(programId).get();
        final suggestedContribution = (program.data()?['suggestedContribution'] ?? 0).toDouble();
        
        updatedParticipants.add(participant.copyWith(
          contributionPaid: monthlyPaid,
          hasPaidContribution: hasPaid,
        ));
      } catch (e) {
        print('❌ Error processing monthly participant ${participant.userId}: $e');
        updatedParticipants.add(participant);
      }
    }
    
    return updatedParticipants;
  });
}

// ✅ Get payment counts per month
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
    print('❌ Error getting monthly payment counts: $e');
    return {};
  }
}
// ✅ FIXED: Monthly financial summary
Stream<Map<String, dynamic>> streamProgramMonthlyFinancialSummary(
  String programId, 
  String monthId
) {
  return streamProgramParticipantsWithMonthlyContributions(programId, monthId)
      .asyncMap((participants) async {
    final program = await _programService.getProgramById(programId);
    
    if (program == null) {
      return {
        'totalParticipants': 0,
        'paidParticipants': 0,
        'pendingParticipants': 0,
        'totalCollected': 0.0,
        'totalExpected': 0.0,
        'collectionRate': 0.0,
      };
    }

    // ✅ Get monthly contributions for total collected
    final monthlyContributions = await _contributionService.getMonthlyContributionsForProgram(
      programId,
      monthId,
    );
    
    final suggestedContribution = program.suggestedContribution ?? 0;
    
    // ✅ FIXED: Calculate paid participants correctly
    int paidParticipants = 0;
    double totalCollected = 0.0;
    
    // Group contributions by user
    final userContributions = <String, double>{};
    for (final contribution in monthlyContributions) {
      userContributions[contribution.userId] = 
          (userContributions[contribution.userId] ?? 0) + contribution.amount;
      totalCollected += contribution.amount;
    }
    
    // Count paid participants
    for (final participant in participants) {
      final userId = participant.userId;
      final userPaid = userContributions[userId] ?? 0;
      
      // ✅ CORRECT LOGIC: Only count as paid if paid full amount for this month
      if (suggestedContribution > 0 && userPaid >= suggestedContribution) {
        paidParticipants++;
      }
    }
    
    final totalExpected = suggestedContribution * participants.length;
    final collectionRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0;

    return {
      'totalParticipants': participants.length,
      'paidParticipants': paidParticipants, // ✅ NOW CORRECT
      'pendingParticipants': participants.length - paidParticipants,
      'totalCollected': totalCollected,
      'totalExpected': totalExpected,
      'collectionRate': collectionRate,
      'suggestedContribution': suggestedContribution,
      'monthId': monthId,
    };
  });
}
  // ✅ ADDED: Stream that includes contribution data for program participants
// ✅ ADDED: Stream that includes contribution data for program participants
Stream<List<ParticipantModel>> streamProgramParticipantsWithContributions(String programId) {
  return _participantService.streamProgramParticipants(programId).asyncMap((participants) async {
    final updatedParticipants = <ParticipantModel>[];
    
    for (final participant in participants) {
      try {
        // Get contribution data for each participant
        final contributions = await _contributionService.getContributionsByUserAndProgram(
          userId: participant.userId,
          programId: programId,
        );
        
        // Calculate total paid
        final totalPaid = contributions.fold(0.0, (sum, contribution) => sum + contribution['amount']);
        
        // Get program to check suggested contribution
        final program = await _firestore.collection('programs').doc(programId).get();
        final suggestedContribution = (program.data()?['suggestedContribution'] ?? 0).toDouble();
        
        updatedParticipants.add(participant.copyWith(
          contributionPaid: totalPaid,
          hasPaidContribution: suggestedContribution > 0 ? totalPaid >= suggestedContribution : false,
        ));
      } catch (e) {
        print('❌ Error processing participant ${participant.userId}: $e');
        // Add participant without contribution data as fallback
        updatedParticipants.add(participant);
      }
    }
    
    return updatedParticipants;
  });
}

// ✅ ADDED: Get program participants with real-time contribution data
Future<List<ParticipantModel>> getProgramParticipantsWithContributions(String programId) async {
  try {
    final participants = await _participantService.getProgramParticipants(programId);
    final updatedParticipants = <ParticipantModel>[];
    
    for (final participant in participants) {
      try {
        // Get contribution data for each participant
        final contributions = await _contributionService.getContributionsByUserAndProgram(
          userId: participant.userId,
          programId: programId,
        );
        
        // Calculate total paid
        final totalPaid = contributions.fold(0.0, (sum, contribution) => sum + contribution['amount']);
        
        // Get program to check suggested contribution
        final program = await _firestore.collection('programs').doc(programId).get();
        final suggestedContribution = (program.data()?['suggestedContribution'] ?? 0).toDouble();
        
        updatedParticipants.add(participant.copyWith(
          contributionPaid: totalPaid,
          hasPaidContribution: suggestedContribution > 0 ? totalPaid >= suggestedContribution : false,
        ));
      } catch (e) {
        print('❌ Error processing participant ${participant.userId}: $e');
        updatedParticipants.add(participant);
      }
    }
    
    return updatedParticipants;
  } catch (e) {
    print('❌ Error getting participants with contributions: $e');
    return [];
  }
}
  // ✅ ADDED: Get program financial summary with real-time data
// ✅ FIXED: Get program financial summary
Future<Map<String, dynamic>> getProgramFinancialSummary(String programId) async {
  try {
    final participants = await getProgramParticipantsWithContributions(programId);
    final program = await _programService.getProgramById(programId);
    
    if (program == null) {
      return {
        'totalParticipants': 0,
        'paidParticipants': 0,
        'pendingParticipants': 0,
        'totalCollected': 0.0,
        'totalExpected': 0.0,
        'collectionRate': 0.0,
      };
    }

    final suggestedContribution = program.suggestedContribution ?? 0;
    
    // ✅ FIXED: Count only participants who paid full amount
    int paidParticipants = 0;
    double totalCollected = 0.0;
    
    for (final participant in participants) {
      final contributionPaid = participant.contributionPaid ?? 0;
      totalCollected += contributionPaid;
      
      // ✅ CORRECT LOGIC: Only count as paid if paid full suggested amount
      if (suggestedContribution > 0 && contributionPaid >= suggestedContribution) {
        paidParticipants++;
      }
    }
    
    final totalExpected = suggestedContribution * participants.length;
    final collectionRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0;

    return {
      'totalParticipants': participants.length,
      'paidParticipants': paidParticipants, // ✅ NOW CORRECT
      'pendingParticipants': participants.length - paidParticipants,
      'totalCollected': totalCollected,
      'totalExpected': totalExpected,
      'collectionRate': collectionRate,
      'suggestedContribution': suggestedContribution,
    };
  } catch (e) {
    print('❌ Error getting financial summary: $e');
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
// ✅ FIXED: Stream program financial summary
Stream<Map<String, dynamic>> streamProgramFinancialSummary(String programId) {
  return streamProgramParticipantsWithContributions(programId).asyncMap((participants) async {
    final program = await _programService.getProgramById(programId);
    
    if (program == null) {
      return {
        'totalParticipants': 0,
        'paidParticipants': 0,
        'pendingParticipants': 0,
        'totalCollected': 0.0,
        'totalExpected': 0.0,
        'collectionRate': 0.0,
      };
    }

    final suggestedContribution = program.suggestedContribution ?? 0;
    
    // ✅ FIXED: Count only participants who paid full amount
    int paidParticipants = 0;
    double totalCollected = 0.0;
    
    for (final participant in participants) {
      final contributionPaid = participant.contributionPaid ?? 0;
      totalCollected += contributionPaid;
      
      // ✅ CORRECT LOGIC: Only count as paid if paid full suggested amount
      if (suggestedContribution > 0 && contributionPaid >= suggestedContribution) {
        paidParticipants++;
      }
    }
    
    final totalExpected = suggestedContribution * participants.length;
    final collectionRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0;

    return {
      'totalParticipants': participants.length,
      'paidParticipants': paidParticipants, // ✅ NOW CORRECT
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

  // ✅ Load community programs
// ✅ Load community programs - MODIFIED to include status sync
Future<void> loadCommunityPrograms(String communityId) async {
  _isLoading = true;
  notifyListeners();
  try {
    // Get programs from service
    _programs = await _programService.getProgramsByCommunity(communityId);
    
    // ✅ CRITICAL: SYNC STATUS FOR ALL LOADED PROGRAMS
    for (final program in _programs) {
      try {
        await program.syncComputedStatusToFirestore();
      } catch (e) {
        print('❌ Error syncing status for program ${program.programId}: $e');
        // Continue with other programs even if one fails
      }
    }
    
  } catch (e) {
    print('Error loading programs: $e');
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
// ✅ ADD THIS METHOD to your ProgramProvider class
Future<void> syncAllProgramsStatus() async {
  try {
    for (final program in _programs) {
      try {
        await program.syncComputedStatusToFirestore();
      } catch (e) {
        print('❌ Error syncing status for program ${program.programId}: $e');
      }
    }
    print('✅ Program status sync completed for ${_programs.length} programs');
  } catch (e) {
    print('❌ Error in syncAllProgramsStatus: $e');
  }
}
  // ✅ Join program - UPDATED for monthly payment program
  Future<void> joinProgram(
    ProgramModel program,
    String userId,
    String userName,
    String userEmail,
    String communityId,
  ) async {
    try {
      final participant = ParticipantModel(
        participantId: '', // Will be generated by Firestore
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

  // ✅ Leave program
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


  // 🆕 ADD REMINDER DATE
  Future<void> addContributionReminderDate(String programId, DateTime date) async {
    try {
      await _programService.addContributionReminderDate(programId, date);
      
      // Update local program if in list
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
      print('❌ Error adding reminder date: $e');
      rethrow;
    }
  }
  
  // 🆕 REMOVE REMINDER DATE
  Future<void> removeContributionReminderDate(String programId, DateTime date) async {
    try {
      await _programService.removeContributionReminderDate(programId, date);
      
      // Update local program
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
      print('❌ Error removing reminder date: $e');
      rethrow;
    }
  }
  
  // 🆕 UPDATE REMINDER SETTINGS
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
      
      // Update local program
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
      print('❌ Error updating reminder settings: $e');
      rethrow;
    }
  }
  
  // 🆕 CLEAR ALL REMINDER DATES
  Future<void> clearAllReminderDates(String programId) async {
    try {
      await _programService.clearAllReminderDates(programId);
      
      // Update local program
      final index = _programs.indexWhere((p) => p.programId == programId);
      if (index != -1) {
        final program = _programs[index];
        _programs[index] = program.copyWith(
          contributionReminderDates: [],
        );
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ Error clearing reminder dates: $e');
      rethrow;
    }
  }




  // 🆕 SEND CONTRIBUTION REMINDER
  Future<void> sendContributionReminder(String programId) async {
    try {
      await _programService.sendContributionReminder(programId);
      notifyListeners();
    } catch (e) {
      print('❌ Error sending reminder: $e');
      rethrow;
    }
  }

  // 🆕 UPDATE REMINDER SETTINGS
// 🆕 UPDATE REMINDER SETTINGS (updated)
Future<void> updateProgramReminderSettings({
  required String programId,
  bool? enableAutoReminders,
  int? reminderDaysBefore,
  String? reminderFrequency,
  List<DateTime>? contributionReminderDates,
  DateTime? firstPaymentDueDate,
  DateTime? nextReminderDate, // ✅ ADD THIS PARAMETER
}) async {
  try {
    await _programService.updateProgramReminderSettings(
      programId: programId,
      enableAutoReminders: enableAutoReminders,
      reminderDaysBefore: reminderDaysBefore,
      reminderFrequency: reminderFrequency,
      contributionReminderDates: contributionReminderDates,
      firstPaymentDueDate: firstPaymentDueDate,
      nextReminderDate: nextReminderDate, // ✅ PASS THIS
    );
    notifyListeners();
  } catch (e) {
    print('❌ Error updating reminder settings: $e');
    rethrow;
  }
}

  // 🆕 GET UPCOMING REMINDERS
  Future<List<ProgramModel>> getProgramsWithUpcomingReminders(String communityId) async {
    try {
      return await _programService.getProgramsWithUpcomingReminders(communityId);
    } catch (e) {
      print('❌ Error getting upcoming reminders: $e');
      return [];
    }
  }

  // 🆕 STREAM UPCOMING REMINDERS
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
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // 🆕 CHECK REMINDER STATUS FOR A PROGRAM
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
      print('❌ Error getting reminder status: $e');
      return {
        'hasReminders': false,
        'nextReminder': null,
        'participantsToNotify': 0,
        'status': 'error',
      };
    }
  }




  // ✅ NEW: Get the monthly payment program for a community
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
          programType: 'monthly', // ✅ ADDED
          isMonthlyPaymentProgram: false,
        ),
      );
    } catch (e) {
      print('❌ Error getting monthly payment program: $e');
      return null;
    }
  }

  // ✅ NEW: Get monthly payment program financial stats
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
      print('❌ Error getting monthly program stats: $e');
      return {
        'hasMonthlyProgram': false,
        'totalCollected': 0.0,
        'totalMembers': 0,
        'paidMembers': 0,
        'balance': 0.0,
      };
    }
  }

  // ✅ NEW: Stream monthly payment program financial stats
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
          programType: 'monthly', // ✅ ADDED
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

  // ✅ Load user participations
  Future<void> loadMyParticipations(String userId, String communityId) async {
    try {
      _myParticipations = await _participantService.getUserProgramParticipations(
        userId,
        communityId,
      );
      notifyListeners();
    } catch (e) {
      print('Error loading participations: $e');
    }
  }

  // ✅ Check if user joined
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

  // ✅ ADD: Real-time stream to check if user joined a specific program
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

  // ✅ ADD: Helper method to get community ID from program
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
        programType: 'general', // ✅ ADDED
        isMonthlyPaymentProgram: false, // ✅ ADDED
      ),
    );
    return program.communityId;
  }

  // ✅ ADD: Better real-time participation watcher
  Map<String, StreamSubscription> _programJoinSubscriptions = {};

  void watchProgramJoinStatus(String programId, String userId, String communityId) {
    // Cancel existing subscription for this program
    _programJoinSubscriptions[programId]?.cancel();

    _programJoinSubscriptions[programId] = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('participations')
        .where('programId', isEqualTo: programId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      // Update local participations list
      final hasJoined = snapshot.docs.isNotEmpty && 
          snapshot.docs.first['status'] == 'joined';
      
      if (hasJoined) {
        // Add to participations if joined
        final participant = ParticipantModel.fromMap(
          snapshot.docs.first.data(), 
          snapshot.docs.first.id
        );
        if (!_myParticipations.any((p) => p.participantId == participant.participantId)) {
          _myParticipations.add(participant);
        }
      } else {
        // Remove from participations if left
        _myParticipations.removeWhere((p) => 
          p.programId == programId && p.userId == userId
        );
      }
      
      notifyListeners();
    });
  }

  // ✅ ADD: Cancel specific program subscription
  void cancelProgramWatch(String programId) {
    _programJoinSubscriptions[programId]?.cancel();
    _programJoinSubscriptions.remove(programId);
  }

  // ✅ Get real-time participant count for a program
  Future<int> getProgramParticipantCount(String programId) async {
    try {
      return await _participantService.getProgramParticipantCount(programId);
    } catch (e) {
      print('Error getting participant count: $e');
      return 0;
    }
  }

  // ✅ Stream for real-time participant count
  Stream<int> streamProgramParticipantCount(String programId) {
    return _participantService.streamProgramParticipantCount(programId);
  }

  // ✅ Get program with real-time participant count
  Future<ProgramModel?> getProgramWithLiveCount(String programId) async {
    try {
      final program = await _programService.getProgramById(programId);
      if (program != null) {
        final participantCount = await getProgramParticipantCount(programId);
        // Return a copy of the program with updated participant count
        return program.copyWith(currentParticipants: participantCount);
      }
      return null;
    } catch (e) {
      print('Error getting program with live count: $e');
      return null;
    }
  }

  // ✅ Stream for program with real-time participant count
  Stream<ProgramModel?> streamProgramWithLiveCount(String programId) {
    return _programService.getProgramStreamById(programId).asyncMap((program) async {
      if (program != null) {
        final participantCount = await getProgramParticipantCount(programId);
        return program.copyWith(currentParticipants: participantCount);
      }
      return null;
    });
  }

  // ✅ Stream community programs with real-time participant counts
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

  // ✅ NEW: Stream programs with financial goals
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

  // ✅ Add contribution
  Future<void> addProgramContribution(ContributionModel contribution) async {
    try {
      await _contributionService.addContribution(contribution);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Get program contributions
  Future<List<ContributionModel>> getProgramContributions(String programId) async {
    try {
      return await _contributionService.getProgramContributions(programId);
    } catch (e) {
      print('Error loading contributions: $e');
      return [];
    }
  }

  Future<List<ProgramModel>> getOngoingPrograms(String communityId) async {
    final programs = await _programService.getActiveProgramsByCommunity(communityId);
    return programs.where((p) => p.isMonthlyPaymentProgram == false).toList();
  }

  // ✅ Get total contributions
  Future<double> getProgramTotalContributions(String programId) async {
    try {
      return await _contributionService.getProgramTotalContributions(programId);
    } catch (e) {
      print('Error calculating total contributions: $e');
      return 0;
    }
  }

  // ✅ NEW: Calculate program financial progress
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
        // Use provided total program amount
        estimatedTotal = program.totalProgramAmount!;
        progressPercentage = estimatedTotal > 0 ? (totalCollected / estimatedTotal) * 100 : 0;
      } else if (program.suggestedContribution != null && program.suggestedContribution! > 0) {
        // Calculate estimated total based on participants
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
      print('Error calculating financial progress: $e');
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

  // ✅ Stream user participations
  Stream<List<ParticipantModel>> streamUserParticipations(String userId, String communityId) {
    return _participantService.streamUserProgramParticipations(userId, communityId);
  }

  // ✅ Stream program total contributions
  Stream<double> streamProgramTotalContributions(String programId) {
    return _contributionService.streamProgramTotalContributions(programId);
  }

  // ✅ Get a single program as a stream
  Stream<ProgramModel?> getProgramById(String programId) {
    return _programService.getProgramStreamById(programId);
  }

  // ✅ Get program participants
  Future<List<ParticipantModel>> getProgramParticipants(String programId) async {
    try {
      return await _participantService.getProgramParticipants(programId);
    } catch (e) {
      print('Error loading program participants: $e');
      return [];
    }
  }

  // ✅ Stream program participants
  Stream<List<ParticipantModel>> streamProgramParticipants(String programId) {
    return _participantService.streamProgramParticipants(programId);
  }

  // ✅ Update program status
  Future<void> updateProgramStatus(String programId, String status) async {
    try {
      await _programService.updateProgramStatus(programId, status);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Update program
  Future<void> updateProgram(ProgramModel program) async {
    try {
      await _programService.updateProgramModel(program);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ NEW: Update program financials only
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

  // ✅ Delete program
  Future<void> deleteProgram(String programId) async {
    try {
      await _programService.deleteProgram(programId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Get participant by program and user
  Future<ParticipantModel?> getParticipantByProgramAndUser(String programId, String userId) async {
    try {
      return await _participantService.getParticipantByProgramAndUser(programId, userId);
    } catch (e) {
      print('Error getting participant: $e');
      return null;
    }
  }

  // ✅ Update participant payment status
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

  // ✅ NEW: Get programs with financial goals
  Future<List<ProgramModel>> getProgramsWithFinancialGoals(String communityId) async {
    try {
      final programs = await _programService.getProgramsWithFinancialGoals(communityId);
      
      // Add real-time participant counts
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
      print('Error loading programs with financial goals: $e');
      return [];
    }
  }

  // ✅ Refresh all data for a community
  Future<void> refreshCommunityData(String communityId, String userId) async {
    await Future.wait([
      loadCommunityPrograms(communityId),
      loadMyParticipations(userId, communityId),
    ]);
  }

  // Add this method to your ProgramProvider class in program_provider.dart

// 🔹 Get participants with monthly payment status
Future<List<Map<String, dynamic>>> getParticipantsWithMonthlyStatus(
  String programId, 
  String monthId,
  String communityId
) async {
  try {
    // Get contribution service instance
    final contributionService = ContributionService();
    
    // Get all approved users in the community
    final usersSnapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('isApproved', isEqualTo: true)
        .get();
    
    // Get monthly payment status for each user
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
    
    // Sort by name
    result.sort((a, b) => (a['userName'] as String).compareTo(b['userName'] as String));
    
    return result;
  } catch (e) {
    print('❌ Error getting participants with monthly status: $e');
    return [];
  }
}

  // ✅ Clear all data
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

// ✅ ADD THIS OUTSIDE AND AFTER ProgramProvider class
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