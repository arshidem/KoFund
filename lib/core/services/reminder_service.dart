import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ReminderService {
  ReminderService();

  Future<Map<String, dynamic>> sendContributionReminders({
    required String communityId,
    required String eventId,
    bool sendTest = false,
    String? testUserId,
  }) async {
    try {
      debugPrint('Calling reminder Cloud Function for event: $eventId');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
            'sendeventContributionReminders',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          );

      final result = await callable.call({
        'communityId': communityId,
        'eventId': eventId,
        'sendTest': sendTest,
        if (testUserId != null) 'testUserId': testUserId,
      });

      return Map<String, dynamic>.from(result.data as Map);
    } catch (error, stackTrace) {
      debugPrint('Error sending contribution reminders: $error');
      debugPrint('Stack trace: $stackTrace');
      return {'success': false, 'message': error.toString()};
    }
  }
}
