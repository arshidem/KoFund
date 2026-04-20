// lib/core/services/program_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/programs/models/program_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_types.dart';
import 'package:kofund/features/participants/models/participant_model.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
class ProgramService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // -------------------------------------------------------------
  // Create Program
  // -------------------------------------------------------------
Future<String> createProgram(ProgramModel program, {bool sendNotification = true}) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final docRef = await _firestore.collection('programs').add(program.toMap());
    final programId = docRef.id;

    if (sendNotification) {
      try {
        // Fetch community name for the notification body
        final communityDoc = await _firestore.collection('communities').doc(program.communityId).get();
        String communityName = communityDoc.data()?['name'] ?? '';
        
        // Fallback: Check user's own data if community doc is missing or name is empty
        if (communityName.isEmpty) {
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          communityName = userDoc.data()?['communityName'] ?? 'Your Community';
        }

        await NotificationService().sendCommunityNotification(
          communityId: program.communityId,
          title: program.title,
          body: 'New program in $communityName · Tap to join',
          type: NotificationType.announcement,
          programId: programId,
          data: {
            'programId': programId,
            'title': program.title,
            'communityName': communityName,
            'type': NotificationType.announcement.name,
            'deepLink': 'program/$programId',
          },
        );
      } catch (e) {
        debugPrint('⚠️ Push notification failed: $e');
      }
    }

    debugPrint('✅ Program created: $programId');
    
    return programId;
  } catch (e) {
    debugPrint('❌ Error creating program: $e');
    throw Exception('Failed to create program: $e');
  }
}
  // -------------------------------------------------------------
  // Get all programs by community (one-time)
  // -------------------------------------------------------------
Future<List<ProgramModel>> getProgramsByCommunity(String communityId) async {
  try {
    debugPrint('📥 Loading programs for community: $communityId');
    
    final snapshot = await _firestore
        .collection('programs')
        .where('communityId', isEqualTo: communityId)
        .orderBy('programDate')
        .limit(100)
        .get();

    // Convert to ProgramModel
    final programs = snapshot.docs
        .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
        .toList();

    debugPrint('✅ Loaded ${programs.length} programs from Firestore');
    
    // 🔄 NEW: Sync status for programs that need updating
    // This now returns updated programs with computed status
    final updatedPrograms = await _syncExpiredProgramsStatus(programs);
    
    return updatedPrograms;
  } catch (e) {
    debugPrint('❌ Error in getProgramsByCommunity: $e');
    throw Exception('Failed to load programs: $e');
  }
}

// ✅ UPDATED: Sync expired programs status and return updated programs
Future<List<ProgramModel>> _syncExpiredProgramsStatus(List<ProgramModel> programs) async {
  try {
    int updatedCount = 0;
    final batch = _firestore.batch();
    final updatedPrograms = <ProgramModel>[];
    final programsToUpdateInFirestore = <ProgramModel>[];
    
    debugPrint('🔄 Checking status for ${programs.length} program(s)');
    
    // Process each program
    for (final program in programs) {
      // Get the computed status from ProgramModel's getter
      final computedStatus = program.computedStatus;
      
      // Create updated program with computed status for memory
      final updatedProgram = program.copyWith(status: computedStatus);
      updatedPrograms.add(updatedProgram);
      
      // Check if we need to update Firestore
      if (computedStatus != program.status) {
        programsToUpdateInFirestore.add(program);
        updatedCount++;
        
        debugPrint('   • "${program.title}": ${program.status} → $computedStatus');
      }
    }
    
    // Batch update Firestore for programs that changed
    if (programsToUpdateInFirestore.isNotEmpty) {
      debugPrint('🔄 Found $updatedCount program(s) needing Firestore update');
      
      for (final program in programsToUpdateInFirestore) {
        final programRef = _firestore
            .collection('programs')
            .doc(program.programId);
        
        batch.update(programRef, {
          'status': program.computedStatus, // Use computed status
          'updatedAt': Timestamp.now(),
        });
      }
      
      debugPrint('🔄 Committing batch update for $updatedCount program(s)...');
      await batch.commit();
      debugPrint('✅ Successfully updated $updatedCount program(s) in Firestore');
    } else {
      debugPrint('✅ All programs already have correct status in Firestore');
    }
    
    // Return the updated programs (with computed status in memory)
    return updatedPrograms;
    
  } catch (e) {
    debugPrint('⚠️ Error syncing program status: $e');
    // If sync fails, return original programs as fallback
    return programs;
  }
}
  // -------------------------------------------------------------
  // Get active programs by community (one-time Future)
  // -------------------------------------------------------------
  Future<List<ProgramModel>> getActiveProgramsByCommunity(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('programs')
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'active')
          .orderBy('programDate')
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load active programs: $e');
    }
  }

  // -------------------------------------------------------------
  // Stream programs by community (real-time)
  // -------------------------------------------------------------
Stream<List<ProgramModel>> streamProgramsByCommunity(String communityId) {
  return _firestore
      .collection('programs')
      .where('communityId', isEqualTo: communityId)
      .limit(100)
      .snapshots()
      .map((snapshot) {
    final programs = snapshot.docs
        .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
        .toList();
    
    // ✅ Fix: Handle null programDate values
    programs.sort((a, b) {
      // If both dates are null, consider them equal
      if (a.programDate == null && b.programDate == null) return 0;
      // Put null dates at the end
      if (a.programDate == null) return 1;
      if (b.programDate == null) return -1;
      // Both are non-null, compare normally
      return a.programDate!.compareTo(b.programDate!);
    });
    
    return programs;
  });
}

  // -------------------------------------------------------------
  // Stream ACTIVE programs by community (real-time)
  // -------------------------------------------------------------
  Stream<List<ProgramModel>> streamActiveProgramsByCommunity(String communityId) {
    return _firestore
        .collection('programs')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'active')
        .orderBy('programDate')
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // -------------------------------------------------------------
  // Get program by ID
  // -------------------------------------------------------------
  Future<ProgramModel?> getProgramById(String programId) async {
    try {
      final doc = await _firestore.collection('programs').doc(programId).get();
      if (doc.exists) {
        return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to load program: $e');
    }
  }

  // -------------------------------------------------------------
  // Stream program by ID
  // -------------------------------------------------------------
  Stream<ProgramModel?> getProgramStreamById(String programId) {
    return _firestore.collection('programs').doc(programId).snapshots().map((doc) {
      if (doc.exists) {
        return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // -------------------------------------------------------------
  // Update program fields (partial)
  // -------------------------------------------------------------
  Future<void> updateProgram(String programId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('programs').doc(programId).update(updates);
    } catch (e) {
      throw Exception('Failed to update program: $e');
    }
  }
// Alias used by some providers: update full model
Future<void> updateProgramModel(ProgramModel program) async {
  try {
    await _firestore.collection('programs').doc(program.programId).update({
      'title': program.title,
      'description': program.description,
      // ✅ Fix: Handle null programDate
      'programDate': program.programDate != null 
          ? Timestamp.fromDate(program.programDate!)
          : null,
      'location': program.location,
      'suggestedContribution': program.suggestedContribution,
      'totalProgramAmount': program.totalProgramAmount,
      'maxParticipants': program.maxParticipants,
      'participantType': program.participantType,
      'status': program.status,
      'programType': program.programType,
      'updatedAt': Timestamp.now(),
      'isMonthlyPaymentProgram': program.isMonthlyPaymentProgram,
    });
  } catch (e) {
    throw Exception('Failed to update program model: $e');
  }
}
  // -------------------------------------------------------------
  // Update program status
  // -------------------------------------------------------------
  Future<void> updateProgramStatus(String programId, String status) async {
    try {
      await _firestore.collection('programs').doc(programId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update program status: $e');
    }
  }

  // -------------------------------------------------------------
  // Delete program
  // -------------------------------------------------------------
  Future<void> deleteProgram(String programId) async {
    try {
      await _firestore.collection('programs').doc(programId).delete();
    } catch (e) {
      throw Exception('Failed to delete program: $e');
    }
  }



  // -------------------------------------------------------------
  // reminderDates field update

  // 🆕 SEND CONTRIBUTION REMINDER FOR A PROGRAM
  Future<void> sendContributionReminder(String programId) async {
    try {
      final program = await getProgramById(programId);
      if (program == null) throw Exception('Program not found');
      
      // Get all participants who haven't fully paid
      final participants = await getParticipantsWithUnpaidContributions(programId);
      
      if (participants.isEmpty) {
        debugPrint('📭 No participants need reminders for program: ${program.title}');
        return;
      }
      
      // Send individual notifications to each participant
      for (final participant in participants) {
        try {
          await _sendParticipantReminder(program, participant);
        } catch (e) {
          debugPrint('⚠️ Failed to send reminder to ${participant.userName}: $e');
        }
      }
      
      // Update next reminder date
      await _updateNextReminderDate(programId);
      
      debugPrint('✅ Sent reminders to ${participants.length} participants for program: ${program.title}');
    } catch (e) {
      debugPrint('❌ Error sending contribution reminders: $e');
      throw Exception('Failed to send reminders: $e');
    }
  }

  Future<List<ParticipantModel>> getParticipantsWithUnpaidContributions(String programId) async {
    try {
      // 🚀 OPTIMIZATION: Filter for unpaid participants at the query level
      final participantsSnapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .where('hasPaidContribution', isEqualTo: false)
          .get();
      
      return participantsSnapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting unpaid participants: $e');
      return [];
    }
  }


  // 🆕 ADD REMINDER DATE
  Future<void> addContributionReminderDate(String programId, DateTime date) async {
    try {
      // Get current program
      final program = await getProgramById(programId);
      if (program == null) throw Exception('Program not found');
      
      // Add new date to list
      final updatedDates = List<DateTime>.from(program.contributionReminderDates)
        ..add(date)
        ..sort(); // Keep dates sorted
      
      await updateProgram(programId, {
        'contributionReminderDates': updatedDates.map((d) => Timestamp.fromDate(d)).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'enableAutoReminders': true, // Auto-enable reminders when dates are added
      });
      
      debugPrint('✅ Added reminder date: ${DateFormat.yMMMd().format(date)}');
    } catch (e) {
      debugPrint('❌ Error adding reminder date: $e');
      throw Exception('Failed to add reminder date: $e');
    }
  }
  
  // 🆕 REMOVE REMINDER DATE
  Future<void> removeContributionReminderDate(String programId, DateTime date) async {
    try {
      final program = await getProgramById(programId);
      if (program == null) throw Exception('Program not found');
      
      // Remove date from list
      final updatedDates = List<DateTime>.from(program.contributionReminderDates)
        ..removeWhere((d) => d.isAtSameMomentAs(date));
      
      await updateProgram(programId, {
        'contributionReminderDates': updatedDates.map((d) => Timestamp.fromDate(d)).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Removed reminder date: ${DateFormat.yMMMd().format(date)}');
    } catch (e) {
      debugPrint('❌ Error removing reminder date: $e');
      throw Exception('Failed to remove reminder date: $e');
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
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (enableAutoReminders != null) updates['enableAutoReminders'] = enableAutoReminders;
      if (reminderDaysBefore != null) updates['reminderDaysBefore'] = reminderDaysBefore;
      if (reminderFrequency != null) updates['reminderFrequency'] = reminderFrequency;
      if (firstPaymentDueDate != null) {
        updates['firstPaymentDueDate'] = Timestamp.fromDate(firstPaymentDueDate);
      }
      
      await _firestore.collection('programs').doc(programId).update(updates);
      
      debugPrint('✅ Updated reminder settings for program: $programId');
    } catch (e) {
      debugPrint('❌ Error updating reminder settings: $e');
      throw Exception('Failed to update reminder settings: $e');
    }
  }
  
  // 🆕 CLEAR ALL REMINDER DATES
  Future<void> clearAllReminderDates(String programId) async {
    try {
      await updateProgram(programId, {
        'contributionReminderDates': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Cleared all reminder dates for program: $programId');
    } catch (e) {
      debugPrint('❌ Error clearing reminder dates: $e');
      throw Exception('Failed to clear reminder dates: $e');
    }
  }


 // 🆕 SEND REMINDER TO INDIVIDUAL PARTICIPANT
Future<void> _sendParticipantReminder(ProgramModel program, ParticipantModel participant) async {
  try {
    final notificationService = NotificationService();
    final programAmount = program.suggestedContribution ?? 0;
    final paidAmount = participant.contributionPaid ?? 0;
    final remainingAmount = programAmount - paidAmount;
    
    // ✅ Fix: Handle null dates properly
    String dueDateText;
    if (program.firstPaymentDueDate != null) {
      dueDateText = DateFormat.yMMMd().format(program.firstPaymentDueDate!);
    } else if (program.programDate != null) {
      dueDateText = DateFormat.yMMMd().format(program.programDate!);
    } else {
      dueDateText = 'Monthly (No specific due date)';
    }
    
    // ✅ Fix: Handle null dates for ISO string
    String dueDateIso;
    if (program.firstPaymentDueDate != null) {
      dueDateIso = program.firstPaymentDueDate!.toIso8601String();
    } else if (program.programDate != null) {
      dueDateIso = program.programDate!.toIso8601String();
    } else {
      dueDateIso = DateTime.now().toIso8601String(); // Fallback to current date
    }
    
    await notificationService.sendUserNotification(
      userId: participant.userId,
      title: 'Contribution Reminder 💰',
      body: 'Reminder for ${program.title}. '
            'Amount: \$${remainingAmount.toStringAsFixed(2)} remaining. '
            'Due date: $dueDateText',
      type: NotificationType.reminder,
      data: {
        'programId': program.programId,
        'programTitle': program.title,
        'remainingAmount': remainingAmount,
        'totalAmount': programAmount,
        'paidAmount': paidAmount,
        'dueDate': dueDateIso,
      },
      programId: program.programId,
      communityId: program.communityId,
      senderName: 'KoFund Reminder System',
    );
    
    debugPrint('📧 Reminder sent to ${participant.userName}');
  } catch (e) {
    debugPrint('❌ Error sending participant reminder: $e');
    rethrow;
  }
}

  // 🆕 UPDATE NEXT REMINDER DATE
  Future<void> _updateNextReminderDate(String programId) async {
    try {
      final program = await getProgramById(programId);
      if (program == null || !program.enableAutoReminders) return;
      
      final nextReminderDate = program.calculateNextReminderDate();
      
      await updateProgram(programId, {
        'nextReminderDate': Timestamp.fromDate(nextReminderDate),
        'lastReminderSent': FieldValue.serverTimestamp(),
      });
      
      debugPrint('📅 Next reminder scheduled for: ${DateFormat.yMMMd().format(nextReminderDate)}');
    } catch (e) {
      debugPrint('⚠️ Error updating next reminder date: $e');
    }
  }

  // 🆕 CHECK AND SEND REMINDERS FOR ALL PROGRAMS
  Future<void> checkAndSendDueReminders() async {
    try {
      debugPrint('🔍 Checking for due reminders...');
      final now = DateTime.now();
      
      // Get all active programs with reminders enabled
      final programsSnapshot = await _firestore
          .collection('programs')
          .where('enableAutoReminders', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(100)
          .get();
      
      int remindersSent = 0;
      
      for (final doc in programsSnapshot.docs) {
        final program = ProgramModel.fromMap(doc.data(), doc.id);
        
        // Check if reminder is due
        if (program.nextReminderDate != null && 
            program.nextReminderDate!.isBefore(now) &&
            program.shouldSendReminder(now)) {
          
          try {
            await sendContributionReminder(program.programId);
            remindersSent++;
          } catch (e) {
            debugPrint('⚠️ Failed to send reminder for program ${program.title}: $e');
          }
        }
      }
      
      debugPrint('✅ Checked ${programsSnapshot.docs.length} programs, sent $remindersSent reminders');
    } catch (e) {
      debugPrint('❌ Error checking reminders: $e');
    }
  }

  // 🆕 UPDATE PROGRAM REMINDER SETTINGS
// 🆕 UPDATE PROGRAM REMINDER SETTINGS (updated)
Future<void> updateProgramReminderSettings({
  required String programId,
  bool? enableAutoReminders,
  int? reminderDaysBefore,
  String? reminderFrequency,
  List<DateTime>? contributionReminderDates,
  DateTime? firstPaymentDueDate,
  DateTime? nextReminderDate, // ✅ ADD THIS
}) async {
  try {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (enableAutoReminders != null) updates['enableAutoReminders'] = enableAutoReminders;
    if (reminderDaysBefore != null) updates['reminderDaysBefore'] = reminderDaysBefore;
    if (reminderFrequency != null) updates['reminderFrequency'] = reminderFrequency;
    if (contributionReminderDates != null) {
      updates['contributionReminderDates'] = contributionReminderDates
          .map((date) => Timestamp.fromDate(date))
          .toList();
    }
    if (firstPaymentDueDate != null) {
      updates['firstPaymentDueDate'] = Timestamp.fromDate(firstPaymentDueDate);
    }
    if (nextReminderDate != null) { // ✅ ADD THIS
      updates['nextReminderDate'] = Timestamp.fromDate(nextReminderDate);
    }
    
    await _firestore.collection('programs').doc(programId).update(updates);
    
    debugPrint('✅ Updated reminder settings for program: $programId');
  } catch (e) {
    debugPrint('❌ Error updating reminder settings: $e');
    throw Exception('Failed to update reminder settings: $e');
  }
}

Future<void> sendProgramContributionReminders({
  required String communityId,
  String? programId,
  bool sendTest = false,
  String? testUserId,
}) async {
  try {
    debugPrint("⏰ Calling Cloud Function: sendProgramContributionReminders");
    
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("❌ User not authenticated");
      return;
    }
    
    final callData = {
      'communityId': communityId,
      if (programId != null) 'programId': programId,
      'sendTest': sendTest,
      if (testUserId != null) 'testUserId': testUserId,
    };
    
    debugPrint("📦 Call data: ${jsonEncode(callData)}");
    
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    
    final callable = functions.httpsCallable(
      'sendProgramContributionReminders',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );
    
    final result = await callable.call(callData);
    
    final resultData = result.data as Map<String, dynamic>;
    debugPrint("✅ Cloud Function Result: $resultData");
    
    if (resultData['success'] == true) {
      debugPrint("✅ Contribution reminders sent successfully");
      debugPrint("📊 ${resultData['remindersSent']} push notifications sent");
      debugPrint("📊 ${resultData['notificationsCreated']} notifications created");
      debugPrint("📊 ${resultData['programsProcessed']} programs processed");
      
      for (final programResult in (resultData['programResults'] as List)) {
        debugPrint("   └ Program: ${programResult['programName']}");
        debugPrint("     Participants needing reminders: ${programResult['participantsNeedingReminders']}");
      }
    } else {
      debugPrint("⚠️ Cloud Function returned: ${resultData['message']}");
      throw Exception(resultData['message']);
    }
    
  } on FirebaseFunctionsException catch (e) {
    debugPrint("❌ FirebaseFunctionsException: ${e.message}");
    debugPrint("📌 Details: ${e.details}");
    debugPrint("📌 Code: ${e.code}");
  } catch (e, stackTrace) {
    debugPrint("❌ Error calling Cloud Function: $e");
    debugPrint("📌 Stack trace: $stackTrace");
  }
}

  // 🆕 GET PROGRAMS WITH UPCOMING REMINDERS
  Future<List<ProgramModel>> getProgramsWithUpcomingReminders(String communityId) async {
    try {
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection('programs')
          .where('communityId', isEqualTo: communityId)
          .where('enableAutoReminders', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .where('nextReminderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('nextReminderDate', isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow))
          .orderBy('nextReminderDate')
          .limit(30)
          .get();
      
      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting programs with upcoming reminders: $e');
      return [];
    }
  }




  // -------------------------------------------------------------
  // Total Contributions for a program (safely parse map)
  // -------------------------------------------------------------
  Future<double> getTotalContributions(String programId) async {
    try {
      final aggregateQuery = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .aggregate(sum('amount'))
          .get();
      return (aggregateQuery.getSum('amount') ?? 0).toDouble();
    } catch (e) {
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Total Expenses for a program (safely parse map)
  // -------------------------------------------------------------
  Future<double> getTotalExpenses(String programId) async {
    try {
      final aggregateQuery = await _firestore
          .collection('expenses')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'approved')
          .aggregate(sum('amount'))
          .get();
      return (aggregateQuery.getSum('amount') ?? 0).toDouble();
    } catch (e) {
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Program financial summary
  // -------------------------------------------------------------
  Future<Map<String, dynamic>> getProgramFinancialSummary(String programId) async {
    final totalContributions = await getTotalContributions(programId);
    final totalExpenses = await getTotalExpenses(programId);
    final balance = totalContributions - totalExpenses;
    return {
      'contributions': totalContributions,
      'expenses': totalExpenses,
      'balance': balance,
    };
  }

  // -------------------------------------------------------------
  // Programs + Stats (streaming helper)
  // returns Stream<List<Map{ 'program': ProgramModel, 'stats': {..} }>>
  // -------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> getProgramsWithStats(String communityId) {
    return streamActiveProgramsByCommunity(communityId).asyncMap((programs) async {
      final List<Map<String, dynamic>> result = [];
      for (final p in programs) {
        final stats = await getProgramFinancialSummary(p.programId);
        result.add({'program': p, 'stats': stats});
      }
      return result;
    });
  }

  // -------------------------------------------------------------
  // Update ONLY financial fields
  // -------------------------------------------------------------
  Future<void> updateProgramFinancials(
    String programId, {
    double? suggestedContribution,
    double? totalProgramAmount,
  }) async {
    try {
      final updates = <String, dynamic>{'updatedAt': Timestamp.now()};
      if (suggestedContribution != null) updates['suggestedContribution'] = suggestedContribution;
      if (totalProgramAmount != null) updates['totalProgramAmount'] = totalProgramAmount;
      await _firestore.collection('programs').doc(programId).update(updates);
    } catch (e) {
      throw Exception('Failed to update financials: $e');
    }
  }

  // -------------------------------------------------------------
  // Get programs with financial goals (one-time)
  // -------------------------------------------------------------
  Future<List<ProgramModel>> getProgramsWithFinancialGoals(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('programs')
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
          .where((p) => p.hasFinancialGoals)
          .toList();
    } catch (e) {
      throw Exception('Failed to load programs with financial goals: $e');
    }
  }

  // -------------------------------------------------------------
  // Stream programs with financial goals
  // -------------------------------------------------------------
  Stream<List<ProgramModel>> streamProgramsWithFinancialGoals(String communityId) {
    return _firestore
        .collection('programs')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
          .where((p) => p.hasFinancialGoals)
          .toList();
    });
  }
  // Add this method to your ProgramService class in program_service.dart

// 🔹 Generate month list for monthly program
List<String> generateMonthList(ProgramModel program) {
  final List<String> months = [];
  
  if (!program.isMonthlyPaymentProgram) {
    return months;
  }
  
  // ✅ Fix: Handle null dates
  final startDate = program.firstPaymentDueDate ?? program.programDate;
  
  // If no start date available, return empty list
  if (startDate == null) {
    debugPrint('⚠️ No start date available for monthly program: ${program.title}');
    return months;
  }
  
  final now = DateTime.now();
  final startYear = startDate.year;
  final startMonth = startDate.month;
  
  // Generate months from start date to current date + 3 months ahead
  for (int i = 0; i < 15; i++) { // 15 months: 12 past + 3 future
    final date = DateTime(startYear, startMonth + i, 1);
    
    // ✅ Fix: startDate is now guaranteed non-null here
    if (date.isBefore(startDate) && i > 0) continue;
    
    // Don't generate too far in the future
    if (date.isAfter(now.add(const Duration(days: 120)))) break;
    
    final monthId = "${date.year}-${date.month.toString().padLeft(2, '0')}";
    months.add(monthId);
  }
  
  return months;
}
// Add this method to ProgramService class in program_service.dart
Future<Map<String, bool>> getMonthlyPaymentStatus(
  String programId, 
  String monthId
) async {
  try {
    final snapshot = await _firestore
        .collection('contributions')
        .where('programId', isEqualTo: programId)
        .where('monthId', isEqualTo: monthId)
        .where('isMonthlyContribution', isEqualTo: true)
        .get();

    final Map<String, bool> paymentStatus = {};
    
    for (final doc in snapshot.docs) {
      final contribution = doc.data();
      final userId = contribution['userId'] as String;
      paymentStatus[userId] = true;
    }
    
    return paymentStatus;
  } catch (e) {
    debugPrint('❌ Error getting monthly payment status: $e');
    return {};
  }
}
// 🔹 Get program participants with monthly payment status
Future<List<Map<String, dynamic>>> getParticipantsWithMonthlyStatus(
  String programId, 
  String monthId,
  String communityId
) async {
  try {
    // First get all approved users in the community
    final usersSnapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .where('isApproved', isEqualTo: true)
        .get();
    
    // Get monthly payment status for each user
    final paymentStatus = await getMonthlyPaymentStatus(programId, monthId);
    
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
    debugPrint('❌ Error getting participants with monthly status: $e');
    return [];
  }
}
}


