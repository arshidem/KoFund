// lib/features/programs/constants/program_types.dart
import 'package:flutter/material.dart';

class ProgramTypes {
  // ✅ SINGLE SOURCE OF TRUTH - Modify only here to update everywhere
  
  // Available program types - ADD/REMOVE/MODIFY ONLY HERE
  static const String general = 'general';
  static const String football = 'football';
  static const String trip = 'trip';
  static const String charity = 'charity';
  static const String festival = 'festival';
  static const String sports = 'sports';
  static const String meeting = 'meeting';
  static const String other = 'other';

  // ✅ Automatically includes all types - NO NEED TO UPDATE MANUALLY
  static List<String> get allTypes => [
    general,
    football,
    trip,
    charity,
    festival,
    sports,
    meeting,
    other,
  ];

  // ✅ Centralized display names - ADD NEW CASES HERE FOR NEW TYPES
  static String getDisplayName(String type) {
    switch (type) {
      case general: return 'General';
      case football: return 'Football';
      case trip: return 'Trip';
      case charity: return 'Charity';
      case festival: return 'Festival';
      case sports: return 'Sports';
      case meeting: return 'Meeting';
      case other: return 'Other';
      default: return 'General'; // Fallback
    }
  }

  // ✅ Centralized descriptions - ADD NEW CASES HERE FOR NEW TYPES
  static String getDescription(String type) {
    switch (type) {
      case general: return 'General purpose program';
      case football: return 'Football match or tournament';
      case trip: return 'Community trip or outing';
      case charity: return 'Charity or fundraising event';
      case festival: return 'Festival or celebration';
      case sports: return 'Sports activities';
      case meeting: return 'Community meeting';
      case other: return 'Other type of program';
      default: return 'General purpose program';
    }
  }

  // ✅ Centralized icons - ADD NEW CASES HERE FOR NEW TYPES
  static IconData getIconData(String type) {
    switch (type) {
      case football: return Icons.sports_soccer;
      case trip: return Icons.card_travel;
      case charity: return Icons.volunteer_activism;
      case festival: return Icons.celebration;
      case sports: return Icons.sports;
      case meeting: return Icons.meeting_room;
      case other: return Icons.category;
      default: return Icons.event; // general & fallback
    }
  }


  
}