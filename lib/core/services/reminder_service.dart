import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:kofund/core/services/event_service.dart';

class ReminderService {
  ReminderService();
  
  Future<Map<String, dynamic>> sendContributionReminders({
    required String communityId,
    required String eventId,
    bool sendTest = false,
    String? testUserId,
  }) async {
    try {
      debugPrint("⏰ Computing reminders locally for event: $eventId");
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("❌ User not authenticated");
        return {'success': false, 'message': 'User not authenticated'};
      }

      final eventService = EventService();
      final event = await eventService.getEventById(eventId);
      if (event == null) {
        return {'success': false, 'message': 'Event not found'};
      }
      
      final participants = await eventService.getParticipantsWithUnpaidContributions(eventId);
      
      int remindersSent = 0;
      
      if (!sendTest) {
        for (final p in participants) {
          try {
            await eventService.sendParticipantReminder(event, p);
            remindersSent++;
          } catch (e) {
            debugPrint("⚠️ Failed to send to ${p.userName}");
          }
        }
        
        // ✅ NEW: Update lastReminderSent to prevent misuse
        if (remindersSent > 0) {
          await eventService.update(eventId, {
            'lastReminderSent': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      return {
        'success': true,
        'isTest': sendTest,
        'eventsProcessed': 1,
        'remindersSent': remindersSent,
        'notificationsCreated': remindersSent,
        'results': [
          {
            'eventId': eventId,
            'name': event.title,
            'participantsNeedingReminders': participants.length,
            'remindersSent': remindersSent,
            'pushNotificationsSent': remindersSent,
          }
        ]
      };
      
    } catch (e, stackTrace) {
      debugPrint("❌ Error computing local reminders: $e");
      debugPrint("📌 Stack trace: $stackTrace");
      return {'success': false, 'message': e.toString()};
    }
  }
}
