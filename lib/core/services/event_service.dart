// lib/core/services/event_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:kofund/features/participants/models/participant_model.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/services/participant_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
class  EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // -------------------------------------------------------------
  // Create event
  // -------------------------------------------------------------
  Future<String> create(EventModel event, {bool sendNotification = true}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final docRef = await _firestore.collection('events').add(event.toMap());
      final eventId = docRef.id;

      if (sendNotification) {
        // 🔥 OPTIMIZATION: Send notification in background to avoid blocking UI
        _sendEventCreationNotification(event, eventId, currentUser.uid);
      }

      debugPrint('✅ event created: $eventId');
      return eventId;
    } catch (e) {
      debugPrint('❌ Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  /// 🚀 Helper to send notifications in background
  Future<void> _sendEventCreationNotification(EventModel event, String eventId, String currentUserId) async {
    try {
      // Fetch community name for the notification body
      final communityDoc = await _firestore.collection('communities').doc(event.communityId).get();
      String communityName = communityDoc.data()?['name'] ?? '';
      
      // Fallback: Check user's own data if community doc is missing or name is empty
      if (communityName.isEmpty) {
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        communityName = userDoc.data()?['communityName'] ?? 'Your Community';
      }

      await NotificationService().sendCommunityNotification(
        communityId: event.communityId,
        title: event.title,
        body: 'New event in $communityName · Tap to join',
        type: NotificationType.announcement,
        eventId: eventId,
        data: {
          'eventId': eventId,
          'title': event.title,
          'communityName': communityName,
          'type': NotificationType.announcement.name,
          'deepLink': 'event/$eventId',
        },
      );
    } catch (e) {
      debugPrint('⚠️ Background event notification failed: $e');
    }
  }
  // -------------------------------------------------------------
  // Get all events by community (one-time)
  // -------------------------------------------------------------
Future<List<EventModel>> getEventsByCommunity(String communityId) async {
  try {
    debugPrint('📥 Loading events for community: $communityId');
    
    final snapshot = await _firestore
        .collection('events')
        .where('communityId', isEqualTo: communityId)
        .limit(100)
        .get();

    // Convert to EventModel
    final events = snapshot.docs
        .map((doc) => EventModel.fromMap(doc.data(), doc.id))
        .toList();

    // Sort in memory to avoid index requirement and excluding events without date
    events.sort((a, b) {
      if (a.eventDate == null && b.eventDate == null) return 0;
      if (a.eventDate == null) return 1;
      if (b.eventDate == null) return -1;
      return a.eventDate!.compareTo(b.eventDate!);
    });

    debugPrint('✅ Loaded ${events.length} events from Firestore');
    
    // 🔄 NEW: Sync status for events that need updating
    final updates = await _syncExpiredStatus(events);
    
    return updates;
  } catch (e) {
    debugPrint('❌ Error in getEventsByCommunity: $e');
    throw Exception('Failed to load events: $e');
  }
}

// ✅ UPDATED: Sync expired events status and return updated events
Future<List<EventModel>> _syncExpiredStatus(List<EventModel> events) async {
  try {
    int updatedCount = 0;
    final batch = _firestore.batch();
    final updates = <EventModel>[];
    final eventsToUpdateInFirestore = <EventModel>[];
    
    debugPrint('🔄 Checking status for ${events.length} event(s)');
    
    // Process each event
    for (final event in events) {
      // Get the computed status from EventModel's getter
      final computedStatus = event.computedStatus;
      
      // Create updated event with computed status for memory
      final update = event.copyWith(status: computedStatus);
      updates.add(update);
      
      // Check if we need to update Firestore
      if (computedStatus != event.status) {
        eventsToUpdateInFirestore.add(event);
        updatedCount++;
        
        debugPrint('   • "${event.title}": ${event.status} → $computedStatus');
      }
    }
    
    // Batch update Firestore for events that changed
    if (eventsToUpdateInFirestore.isNotEmpty) {
      debugPrint('🔄 Found $updatedCount event(s) needing Firestore update');
      
      for (final event in eventsToUpdateInFirestore) {
        final ef = _firestore
            .collection('events')
            .doc(event.eventId);
        
        batch.update(ef, {
          'status': event.computedStatus, // Use computed status
          'updatedAt': Timestamp.now(),
        });
      }
      
      debugPrint('🔄 Committing batch update for $updatedCount event(s)...');
      await batch.commit();
      debugPrint('✅ Successfully updated $updatedCount event(s) in Firestore');
    } else {
      debugPrint('✅ All events already have correct status in Firestore');
    }
    
    // Return the updated events (with computed status in memory)
    return updates;
    
  } catch (e) {
    debugPrint('⚠️ Error syncing event status: $e');
    // If sync fails, return original events as fallback
    return events;
  }
}
  // -------------------------------------------------------------
  // Get active events by community (one-time Future)
  // -------------------------------------------------------------
  Future<List<EventModel>> getActiveEventsByCommunity(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'active')
          .limit(50)
          .get();

      final events = snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort in memory
      events.sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });

      return events;
    } catch (e) {
      throw Exception('Failed to load active events: $e');
    }
  }

  // -------------------------------------------------------------
  // Stream events by community (real-time)
  // -------------------------------------------------------------
Stream<List<EventModel>> streamEventsByCommunity(String communityId) {
  return _firestore
      .collection('events')
      .where('communityId', isEqualTo: communityId)
      .limit(100)
      .snapshots()
      .map((snapshot) {
    final events = snapshot.docs
        .map((doc) => EventModel.fromMap(doc.data(), doc.id))
        .toList();
    
    // ✅ Fix: Handle null eventDate values
    events.sort((a, b) {
      // If both dates are null, consider them equal
      if (a.eventDate == null && b.eventDate == null) return 0;
      // Put null dates at the end
      if (a.eventDate == null) return 1;
      if (b.eventDate == null) return -1;
      // Both are non-null, compare normally
      return a.eventDate!.compareTo(b.eventDate!);
    });
    
    return events;
  });
}

  // -------------------------------------------------------------
  // Stream ACTIVE events by community (real-time)
  // -------------------------------------------------------------
  Stream<List<EventModel>> streamActiveEventsByCommunity(String communityId) {
    return _firestore
        .collection('events')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'active')
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .toList();
      
      // Sort in memory
      events.sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });
      
      return events;
    });
  }

  // -------------------------------------------------------------
  // Get event by ID
  // -------------------------------------------------------------
  Future<EventModel?> getEventById(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();
      if (doc.exists) {
        return EventModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to load event: $e');
    }
  }

  // -------------------------------------------------------------
  // Stream event by ID
  // -------------------------------------------------------------
  Stream<EventModel?> getEventStreamById(String eventId) {
    return _firestore.collection('events').doc(eventId).snapshots().map((doc) {
      if (doc.exists) {
        return EventModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // -------------------------------------------------------------
  // Update event fields (partial)
  // -------------------------------------------------------------
  Future<void> update(String eventId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('events').doc(eventId).update(updates);
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }
// Alias used by some providers: update full model
Future<void> updateModel(EventModel event) async {
  try {
    await _firestore.collection('events').doc(event.eventId).update({
      'title': event.title,
      'description': event.description,
      // ✅ Fix: Handle null eventDate
      'eventDate': event.eventDate != null 
          ? Timestamp.fromDate(event.eventDate!)
          : null,
      'location': event.location,
      'suggestedContribution': event.suggestedContribution,
      'totalAmount': event.totalAmount,
      'maxParticipants': event.maxParticipants,
      'participantType': event.participantType,
      'status': event.status,
      'eventType': event.eventType,
      'updatedAt': Timestamp.now(),
      'isMonthlyPayment': event.isMonthlyPayment,
      'isPublicEnabled': event.isPublicEnabled,
      'publicPassword': event.publicPassword,
    });
  } catch (e) {
    throw Exception('Failed to update event model: $e');
  }
}
  // -------------------------------------------------------------
  // Update event status
  // -------------------------------------------------------------
  Future<void> updateStatus(String eventId, String status) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update event status: $e');
    }
  }

  // -------------------------------------------------------------
  // Delete event
  // -------------------------------------------------------------
  Future<void> delete(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }



  // -------------------------------------------------------------
  // reminderDates field update

  // 🆕 SEND CONTRIBUTION REMINDER FOR A event
  Future<void> sendContributionReminder(String eventId) async {
    try {
      final event = await getEventById(eventId);
      if (event == null) throw Exception('event not found');
      
      // Get all participants who haven't fully paid
      final participants = await getParticipantsWithUnpaidContributions(
        eventId,
        communityId: event.communityId,
      );
      
      if (participants.isEmpty) {
        debugPrint('📭 No participants need reminders for event: ${event.title}');
        return;
      }
      
      // Send individual notifications to each participant
      for (final participant in participants) {
        try {
          await sendParticipantReminder(event, participant);
        } catch (e) {
          debugPrint('⚠️ Failed to send reminder to ${participant.userName}: $e');
        }
      }
      
      // Update next reminder date
      await _updateNextReminderDate(eventId);
      
      debugPrint('✅ Sent reminders to ${participants.length} participants for event: ${event.title}');
    } catch (e) {
      debugPrint('❌ Error sending contribution reminders: $e');
      throw Exception('Failed to send reminders: $e');
    }
  }

  Future<List<ParticipantModel>> getParticipantsWithUnpaidContributions(String eventId, {String? communityId}) async {
    try {
      // 🚀 OPTIMIZATION: Filter for unpaid participants at the query level
      var query = _firestore
          .collection('participants')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'joined');
      
      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final participantsSnapshot = await query.get();
      
      return participantsSnapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data(), doc.id))
          .where((p) => p.hasPaidContribution == false)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting unpaid participants: $e');
      return [];
    }
  }


  // 🆕 ADD REMINDER DATE
  Future<void> addContributionReminderDate(String eventId, DateTime date) async {
    try {
      // Get current event
      final event = await getEventById(eventId);
      if (event == null) throw Exception('event not found');
      
      // Add new date to list
      final updatedDates = List<DateTime>.from(event.contributionReminderDates)
        ..add(date)
        ..sort(); // Keep dates sorted
      
      await update(eventId, {
        'contributionReminderDates': updatedDates.map((eventId) => Timestamp.fromDate(eventId)).toList(),
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
  Future<void> removeContributionReminderDate(String eventId, DateTime date) async {
    try {
      final event = await getEventById(eventId);
      if (event == null) throw Exception('event not found');
      
      // Remove date from list
      final updatedDates = List<DateTime>.from(event.contributionReminderDates)
        ..removeWhere((eventId) => eventId.isAtSameMomentAs(date));
      
      await update(eventId, {
        'contributionReminderDates': updatedDates.map((eventId) => Timestamp.fromDate(eventId)).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Removed reminder date: ${DateFormat.yMMMd().format(date)}');
    } catch (e) {
      debugPrint('❌ Error removing reminder date: $e');
      throw Exception('Failed to remove reminder date: $e');
    }
  }
  

  
  // 🆕 CLEAR ALL REMINDER DATES
  Future<void> clearAllReminderDates(String eventId) async {
    try {
      await update(eventId, {
        'contributionReminderDates': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Cleared all reminder dates for event: $eventId');
    } catch (e) {
      debugPrint('❌ Error clearing reminder dates: $e');
      throw Exception('Failed to clear reminder dates: $e');
    }
  }


 // 🆕 SEND REMINDER TO INDIVIDUAL PARTICIPANT
Future<void> sendParticipantReminder(EventModel event, ParticipantModel participant) async {
  try {
    final notificationService = NotificationService();
    final amount = event.suggestedContribution ?? 0;
    final paidAmount = participant.contributionPaid ?? 0;
    final remainingAmount = amount - paidAmount;
    
    // ✅ NEW CHECK: Only send to non-contributed or partially-contributed users
    if (amount > 0 && remainingAmount <= 0) {
      debugPrint('🔕 Participant ${participant.userName} has already fully paid. Skipping.');
      return;
    }
    
    // ✅ Fix: Handle null dates properly
    String dueDateText;
    if (event.firstPaymentDueDate != null) {
      dueDateText = DateFormat.yMMMd().format(event.firstPaymentDueDate!);
    } else if (event.eventDate != null) {
      dueDateText = DateFormat.yMMMd().format(event.eventDate!);
    } else {
      dueDateText = 'Monthly (No specific due date)';
    }
    
    // ✅ Fix: Handle null dates for ISO string
    String dueDateIso;
    if (event.firstPaymentDueDate != null) {
      dueDateIso = event.firstPaymentDueDate!.toIso8601String();
    } else if (event.eventDate != null) {
      dueDateIso = event.eventDate!.toIso8601String();
    } else {
      dueDateIso = DateTime.now().toIso8601String(); // Fallback to current date
    }
    
    final defaultTitle = 'Contribution Reminder 💰';
    final remainingAmountText = '₹${remainingAmount.toStringAsFixed(0)}';
    final defaultMessage = 'Remaining balance: $remainingAmountText for ${event.title}. Due by $dueDateText';
    
    String finalBody = event.customReminderMessage?.isNotEmpty == true 
        ? event.customReminderMessage! 
        : defaultMessage;
        
    // Support placeholder replacement in custom messages
    finalBody = finalBody.replaceAll('{remaining_amount}', remainingAmountText);
    finalBody = finalBody.replaceAll('{event_title}', event.title);
    finalBody = finalBody.replaceAll('{due_date}', dueDateText);
          
    await notificationService.sendUserNotification(
      userId: participant.userId,
      title: event.customReminderTitle?.isNotEmpty == true ? event.customReminderTitle! : defaultTitle,
      body: finalBody,
      type: NotificationType.reminder,
      data: {
        'eventId': event.eventId,
        'title': event.title,
        'remainingAmount': remainingAmount,
        'totalAmount': amount,
        'paidAmount': paidAmount,
        'dueDate': dueDateIso,
      },
      eventId: event.eventId,
      communityId: event.communityId,
      senderName: 'KoFund Reminder System',
    );
    
    debugPrint('📧 Reminder sent to ${participant.userName}');
  } catch (e) {
    debugPrint('❌ Error sending participant reminder: $e');
    rethrow;
  }
}

  // 🆕 UPDATE NEXT REMINDER DATE
  Future<void> _updateNextReminderDate(String eventId) async {
    try {
      final event = await getEventById(eventId);
      if (event == null || !event.enableAutoReminders) return;
      
      final nextReminderDate = event.calculateNextReminderDate();
      
      final dataParams = <String, dynamic>{
        'lastReminderSent': FieldValue.serverTimestamp(),
      };
      
      if (nextReminderDate != null) {
        dataParams['nextReminderDate'] = Timestamp.fromDate(nextReminderDate);
      } else {
        dataParams['nextReminderDate'] = FieldValue.delete();
      }
      
      await update(eventId, dataParams);
      
      if (nextReminderDate != null) {
        debugPrint('📅 Next reminder scheduled for: ${DateFormat.yMMMd().format(nextReminderDate)}');
      } else {
        debugPrint('📅 Auto-reminders exhausted/disabled for now.');
      }
    } catch (e) {
      debugPrint('⚠️ Error updating next reminder date: $e');
    }
  }

  // 🆕 CHECK AND SEND REMINDERS FOR ALL 
  Future<void> checkAndSendDueReminders({String? communityId}) async {
    try {
      debugPrint('🔍 Checking for due reminders...');
      final now = DateTime.now();
      
      // Get all active events with reminders enabled
      var query = _firestore
          .collection('events')
          .where('enableAutoReminders', isEqualTo: true)
          .where('status', isEqualTo: 'active');

      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      final eventsSnapshot = await query.limit(100).get();
      
      int remindersSent = 0;
      
      for (final doc in eventsSnapshot.docs) {
        final event = EventModel.fromMap(doc.data(), doc.id);
        
        // Check if reminder is due
        if (event.nextReminderDate != null && 
            event.nextReminderDate!.isBefore(now)) {
          
          try {
            await sendContributionReminder(event.eventId);
            remindersSent++;
          } catch (e) {
            debugPrint('⚠️ Failed to send reminder for event ${event.title}: $e');
          }
        }
      }
      
      debugPrint('✅ Checked ${eventsSnapshot.docs.length} events, sent $remindersSent reminders');
    } catch (e) {
      debugPrint('❌ Error checking reminders: $e');
    }
  }

  // 🆕 UPDATE event REMINDER SETTINGS
// 🆕 UPDATE event REMINDER SETTINGS (updated)
Future<void> updateReminderSettings({
  required String eventId,
  bool? enableAutoReminders,
  int? reminderDaysBefore,
  String? reminderFrequency,
  List<DateTime>? contributionReminderDates,
  DateTime? firstPaymentDueDate,
  DateTime? nextReminderDate,
  String? customReminderTitle,
  String? customReminderMessage,
  bool? enableReminderRetries,
  int? retryDaysAfter,
  bool? enableAdminEscalation,
  int? escalationDaysAfter,
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
    if (nextReminderDate != null) { 
      updates['nextReminderDate'] = Timestamp.fromDate(nextReminderDate);
    }
    if (customReminderTitle != null) updates['customReminderTitle'] = customReminderTitle;
    if (customReminderMessage != null) updates['customReminderMessage'] = customReminderMessage;
    if (enableReminderRetries != null) updates['enableReminderRetries'] = enableReminderRetries;
    if (retryDaysAfter != null) updates['retryDaysAfter'] = retryDaysAfter;
    if (enableAdminEscalation != null) updates['enableAdminEscalation'] = enableAdminEscalation;
    if (escalationDaysAfter != null) updates['escalationDaysAfter'] = escalationDaysAfter;
    
    await _firestore.collection('events').doc(eventId).update(updates);
    
    debugPrint('✅ Updated reminder settings for event: $eventId');
  } catch (e) {
    debugPrint('❌ Error updating reminder settings: $e');
    throw Exception('Failed to update reminder settings: $e');
  }
}

Future<void> sendContributionReminders({
  required String communityId,
  String? eventId,
  bool sendTest = false,
  String? testUserId,
}) async {
  try {
    debugPrint("⏰ Calling Cloud Function: sendContributionReminders");
    
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("❌ User not authenticated");
      return;
    }
    
    final callData = {
      'communityId': communityId,
      if (eventId != null) 'eventId': eventId,
      'sendTest': sendTest,
      if (testUserId != null) 'testUserId': testUserId,
    };
    
    debugPrint("📦 Call data: ${jsonEncode(callData)}");
    
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    
    final callable = functions.httpsCallable(
      'sendContributionReminders',
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
      debugPrint("📊 ${resultData['eventsProcessed']} events processed");
      
      for (final result in (resultData['results'] as List)) {
        debugPrint("   └ event: ${result['name']}");
        debugPrint("     Participants needing reminders: ${result['participantsNeedingReminders']}");
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

  // 🆕 GET  WITH UPCOMING REMINDERS
  Future<List<EventModel>> getEventsWithUpcomingReminders(String communityId) async {
    try {
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection('events')
          .where('communityId', isEqualTo: communityId)
          .where('enableAutoReminders', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .where('nextReminderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('nextReminderDate', isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow))
          .orderBy('nextReminderDate')
          .limit(30)
          .get();
      
      return snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting events with upcoming reminders: $e');
      return [];
    }
  }




  // -------------------------------------------------------------
  // Total Contributions for a event (safely parse map)
  // -------------------------------------------------------------
  Future<double> getTotalContributions(String eventId, {String? communityId}) async {
    try {
      var query = _firestore
          .collection('contributions')
          .where('eventId', isEqualTo: eventId);
      
      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final aggregateQuery = await query.aggregate(sum('amount')).get();
      return (aggregateQuery.getSum('amount') ?? 0).toDouble();
    } catch (e) {
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Total Expenses for a event (safely parse map)
  // -------------------------------------------------------------
  Future<double> getTotalExpenses(String eventId, {String? communityId}) async {
    try {
      var query = _firestore
          .collection('expenses')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'approved');
      
      if (communityId != null && communityId.isNotEmpty) {
        query = query.where('communityId', isEqualTo: communityId);
      }
      
      final aggregateQuery = await query.aggregate(sum('amount')).get();
      return (aggregateQuery.getSum('amount') ?? 0).toDouble();
    } catch (e) {
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // event financial summary
  // -------------------------------------------------------------
  Future<Map<String, dynamic>> getFinancialSummary(String eventId, {String? communityId}) async {
    final totalContributions = await getTotalContributions(eventId, communityId: communityId);
    final totalExpenses = await getTotalExpenses(eventId, communityId: communityId);
    final balance = totalContributions - totalExpenses;
    return {
      'contributions': totalContributions,
      'expenses': totalExpenses,
      'balance': balance,
    };
  }

  // -------------------------------------------------------------
  // events + Stats (streaming helper)
  // returns Stream<List<Map{ 'event': EventModel, 'stats': {..} }>>
  // -------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> getEventsWithStats(String communityId) {
    return streamActiveEventsByCommunity(communityId).asyncMap((events) async {
      final List<Map<String, dynamic>> result = [];
      for (final p in events) {
        final stats = await getFinancialSummary(p.eventId, communityId: communityId);
        result.add({'event': p, 'stats': stats});
      }
      return result;
    });
  }

  // -------------------------------------------------------------
  // Update ONLY financial fields
  // -------------------------------------------------------------
  Future<void> updateFinancials(
    String eventId, {
    double? suggestedContribution,
    double? totalAmount,
  }) async {
    try {
      final updates = <String, dynamic>{'updatedAt': Timestamp.now()};
      if (suggestedContribution != null) updates['suggestedContribution'] = suggestedContribution;
      if (totalAmount != null) updates['totalAmount'] = totalAmount;
      await _firestore.collection('events').doc(eventId).update(updates);
    } catch (e) {
      throw Exception('Failed to update financials: $e');
    }
  }

  // -------------------------------------------------------------
  // Get events with financial goals (one-time)
  // -------------------------------------------------------------
  Future<List<EventModel>> getEventsWithFinancialGoals(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .where((p) => p.hasFinancialGoals)
          .toList();
    } catch (e) {
      throw Exception('Failed to load events with financial goals: $e');
    }
  }

  // -------------------------------------------------------------
  // Stream events with financial goals
  // -------------------------------------------------------------
  Stream<List<EventModel>> streasWithFinancialGoals(String communityId) {
    return _firestore
        .collection('events')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .where((p) => p.hasFinancialGoals)
          .toList();
    });
  }
  // Add this method to your  EventService class in event_service.dart

// 🔹 Generate month list for monthly event
List<String> generateMonthList(EventModel event) {
  final List<String> months = [];
  
  if (!event.isMonthlyPayment) {
    return months;
  }
  
  // ✅ Fix: Handle null dates
  final startDate = event.firstPaymentDueDate ?? event.eventDate;
  
  // If no start date available, return empty list
  if (startDate == null) {
    debugPrint('⚠️ No start date available for monthly event: ${event.title}');
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
// Add this method to  EventService class in event_service.dart
Future<Map<String, bool>> getMonthlyPaymentStatus(
  String eventId, 
  String monthId
) async {
  try {
    final snapshot = await _firestore
        .collection('contributions')
        .where('eventId', isEqualTo: eventId)
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
// 🔹 Get event participants with monthly payment status
Future<List<Map<String, dynamic>>> getParticipantsWithMonthlyStatus(
  String eventId, 
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
    final paymentStatus = await getMonthlyPaymentStatus(eventId, monthId);
    
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







