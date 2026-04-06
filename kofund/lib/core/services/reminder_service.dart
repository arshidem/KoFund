import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ReminderService {
  final FirebaseFunctions _functions;
  
  ReminderService() : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  
  // Helper methods - MOVE THESE OUTSIDE THE MAIN METHOD
  Map<String, dynamic> _convertMap(Map<dynamic, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      
      if (value is Map) {
        result[key] = _convertMap(value);
      } else if (value is List) {
        result[key] = _convertList(value);
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }
  
  Future<Map<String, dynamic>> sendProgramContributionReminders({
    required String communityId,
    required String programId,
    bool sendTest = false,
    String? testUserId,
  }) async {
    try {
      debugPrint("⏰ Calling Cloud Function: sendProgramContributionReminders");
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("❌ User not authenticated");
        throw Exception("User not authenticated");
      }
      
      final now = DateTime.now();
      final baseNotificationId = '${now.millisecondsSinceEpoch}';
      
      final callData = {
        'communityId': communityId,
        'programId': programId,
        'sendTest': sendTest,
        'testUserId': testUserId,
        'data': {
          'senderId': currentUser.uid,
          'sentFromApp': true,
          'notificationId': baseNotificationId,
        },
      };
      
      debugPrint("📦 Call data: ${jsonEncode(callData)}");
      
      final callable = _functions.httpsCallable(
        'sendProgramContributionReminders',
        options: HttpsCallableOptions(timeout: Duration(seconds: 60)),
      );
      
      // ✅ FIXED: Remove duplicate variable declaration
      final response = await callable.call(callData);
      
      // ✅ ABSOLUTELY SAFE CASTING
      Map<String, dynamic> resultData = {};

      if (response.data != null && response.data is Map) {
        final dynamic rawResponse = response.data;
        final Map<dynamic, dynamic> rawData = rawResponse as Map<dynamic, dynamic>;
        
        // Convert all keys to String
        for (final entry in rawData.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          
          // Handle nested maps
          if (value is Map) {
            resultData[key] = _convertMap(value);
          } 
          // Handle nested lists
          else if (value is List) {
            resultData[key] = _convertList(value);
          }
          else {
            resultData[key] = value;
          }
        }
      } else {
        throw Exception('Invalid response from Cloud Function');
      }

      debugPrint("✅ Cloud Function Result: $resultData");
      return resultData;
      
    } on FirebaseFunctionsException catch (e) {
      debugPrint("❌ Firebase Functions Error:");
      debugPrint("   Code: ${e.code}");
      debugPrint("   Message: ${e.message}");
      debugPrint("   Details: ${e.details}");
      rethrow;
    } catch (e, stackTrace) {
      debugPrint("❌ Error calling Cloud Function: $e");
      debugPrint("📌 Stack trace: $stackTrace");
      rethrow;
    }
  }
}
