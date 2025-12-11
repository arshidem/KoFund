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
Future<String> createProgram(ProgramModel program) async {
  try {
    // Get current user info for notification
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // 1. Create program in Firestore
    final docRef = await _firestore.collection('programs').add(program.toMap());
    final programId = docRef.id;
    
    // 2. Create updated program model with ID
    final createdProgram = program.copyWith(programId: programId);
    
    // 3. 🆕 SEND NOTIFICATION TO COMMUNITY
    try {
      // Import NotificationService at the top of your file:
      // import 'package:kofund/core/services/notification_service.dart';
      final notificationService = NotificationService();
      
      await notificationService.sendCommunityNotification(
        communityId: program.communityId,
        title: 'New Program Created 🎯',
        body: '${program.title} has been created. ${program.description}',
        type: NotificationType.program,
        data: {
          'programId': programId,
          'createdBy': currentUser.uid,
          'createdByName': currentUser.displayName ?? 'User',
        },
        programId: programId,
        senderName: currentUser.displayName ?? 'User',
      );
      print('📢 Community notification sent for new program: $programId');
    } catch (notificationError) {
      print('⚠️ Failed to send notification (non-critical): $notificationError');
      // Don't fail the program creation if notification fails
    }

    print('✅ Program created: $programId');
    
    return programId;
  } catch (e) {
    print('❌ Error creating program: $e');
    throw Exception('Failed to create program: $e');
  }
}
  // -------------------------------------------------------------
  // Get all programs by community (one-time)
  // -------------------------------------------------------------
  Future<List<ProgramModel>> getProgramsByCommunity(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('programs')
          .where('communityId', isEqualTo: communityId)
          .orderBy('programDate')
          .get();

      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load programs: $e');
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
          .get();

      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
        .snapshots()
        .map((snapshot) {
      final programs = snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      programs.sort((a, b) => a.programDate.compareTo(b.programDate));
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
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
        'programDate': Timestamp.fromDate(program.programDate),
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
        print('📭 No participants need reminders for program: ${program.title}');
        return;
      }
      
      // Send individual notifications to each participant
      for (final participant in participants) {
        try {
          await _sendParticipantReminder(program, participant);
        } catch (e) {
          print('⚠️ Failed to send reminder to ${participant.userName}: $e');
        }
      }
      
      // Update next reminder date
      await _updateNextReminderDate(programId);
      
      print('✅ Sent reminders to ${participants.length} participants for program: ${program.title}');
    } catch (e) {
      print('❌ Error sending contribution reminders: $e');
      throw Exception('Failed to send reminders: $e');
    }
  }

  // 🆕 GET PARTICIPANTS WITH UNPAID CONTRIBUTIONS
  Future<List<ParticipantModel>> getParticipantsWithUnpaidContributions(String programId) async {
    try {
      // Get all participants for the program
      final participantsSnapshot = await _firestore
          .collection('participants') // Adjust to your collection name
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .get();
      
      final participants = participantsSnapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Filter participants who haven't fully paid
      return participants.where((participant) => !participant.hasPaidContribution).toList();
    } catch (e) {
      print('❌ Error getting unpaid participants: $e');
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
      
      print('✅ Added reminder date: ${DateFormat.yMMMd().format(date)}');
    } catch (e) {
      print('❌ Error adding reminder date: $e');
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
      
      print('✅ Removed reminder date: ${DateFormat.yMMMd().format(date)}');
    } catch (e) {
      print('❌ Error removing reminder date: $e');
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
      
      print('✅ Updated reminder settings for program: $programId');
    } catch (e) {
      print('❌ Error updating reminder settings: $e');
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
      
      print('✅ Cleared all reminder dates for program: $programId');
    } catch (e) {
      print('❌ Error clearing reminder dates: $e');
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
      
      await notificationService.sendUserNotification(
        userId: participant.userId,
        title: 'Contribution Reminder 💰',
        body: 'Reminder for ${program.title}. '
              'Amount: \$${remainingAmount.toStringAsFixed(2)} remaining. '
              'Due date: ${DateFormat.yMMMd().format(program.firstPaymentDueDate ?? program.programDate)}',
        type: NotificationType.reminder,
        data: {
          'programId': program.programId,
          'programTitle': program.title,
          'remainingAmount': remainingAmount,
          'totalAmount': programAmount,
          'paidAmount': paidAmount,
          'dueDate': program.firstPaymentDueDate?.toIso8601String() ?? program.programDate.toIso8601String(),
        },
        programId: program.programId,
        communityId: program.communityId,
        senderName: 'KoFund Reminder System',
      );
      
      print('📧 Reminder sent to ${participant.userName}');
    } catch (e) {
      print('❌ Error sending participant reminder: $e');
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
      
      print('📅 Next reminder scheduled for: ${DateFormat.yMMMd().format(nextReminderDate)}');
    } catch (e) {
      print('⚠️ Error updating next reminder date: $e');
    }
  }

  // 🆕 CHECK AND SEND REMINDERS FOR ALL PROGRAMS
  Future<void> checkAndSendDueReminders() async {
    try {
      print('🔍 Checking for due reminders...');
      final now = DateTime.now();
      
      // Get all active programs with reminders enabled
      final programsSnapshot = await _firestore
          .collection('programs')
          .where('enableAutoReminders', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .get();
      
      int remindersSent = 0;
      
      for (final doc in programsSnapshot.docs) {
        final program = ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        
        // Check if reminder is due
        if (program.nextReminderDate != null && 
            program.nextReminderDate!.isBefore(now) &&
            program.shouldSendReminder(now)) {
          
          try {
            await sendContributionReminder(program.programId);
            remindersSent++;
          } catch (e) {
            print('⚠️ Failed to send reminder for program ${program.title}: $e');
          }
        }
      }
      
      print('✅ Checked ${programsSnapshot.docs.length} programs, sent $remindersSent reminders');
    } catch (e) {
      print('❌ Error checking reminders: $e');
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
    
    print('✅ Updated reminder settings for program: $programId');
  } catch (e) {
    print('❌ Error updating reminder settings: $e');
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
          .get();
      
      return snapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('❌ Error getting programs with upcoming reminders: $e');
      return [];
    }
  }




  // -------------------------------------------------------------
  // Total Contributions for a program (safely parse map)
  // -------------------------------------------------------------
  Future<double> getTotalContributions(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0);
        total += (amount is num) ? amount.toDouble() : double.tryParse('$amount') ?? 0.0;
      }
      return total;
    } catch (e) {
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Total Expenses for a program (safely parse map)
  // -------------------------------------------------------------
  Future<double> getTotalExpenses(String programId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'approved')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0);
        total += (amount is num) ? amount.toDouble() : double.tryParse('$amount') ?? 0.0;
      }
      return total;
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
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
          .map((doc) => ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((p) => p.hasFinancialGoals)
          .toList();
    });
  }
}
