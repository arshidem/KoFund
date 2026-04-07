import 'package:flutter/material.dart';

class CommunityType {
  // Community Type Constants
  static const String apartment = 'Apartment';
  static const String residential = 'Residential';
  static const String club = 'Club';
  static const String sports = 'Sports Club';
  static const String religious = 'Religious';
  static const String office = 'Office';
  static const String education = 'Education';
  static const String family = 'Family';
  static const String friends = 'Friends';
  static const String other = 'Other';
  
  // Get all types as list
  static List<String> get allTypes => [
    apartment,
    residential,
    club,
    sports,
    religious,
    office,
    education,
    family,
    friends,
    other,
  ];
  
  // Get Material Icons for each type
  static IconData getMaterialIcon(String type) {
    switch (type) {
      case apartment:
        return Icons.apartment_rounded;
      case residential:
        return Icons.location_city_rounded;
      case club:
        return Icons.groups_rounded;
      case sports:
        return Icons.sports_basketball_rounded;
      case religious:
        return Icons.church_rounded;
      case office:
        return Icons.business_center_rounded;
      case education:
        return Icons.school_rounded;
      case family:
        return Icons.family_restroom_rounded;
      case friends:
        return Icons.people_alt_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  // Get icons for each type (for legacy UI support)
  static String getIcon(String type) {
    switch (type) {
      case apartment:
      case residential:
        return '🏢';
      case club:
        return '🎯';
      case sports:
        return '⚽';
      case religious:
        return '🛕';
      case office:
        return '💼';
      case education:
        return '🎓';
      case family:
        return '👨‍👩‍👧‍👦';
      case friends:
        return '👥';
      default:
        return '🏠';
    }
  }

  // Get description for each type (required by providers)
  static String getDescription(String type) {
    switch (type) {
      case apartment:
        return 'Apartment building or complex';
      case residential:
        return 'Residential society or gated community';
      case club:
        return 'Social or professional club';
      case sports:
        return 'Sports team or athletic group';
      case religious:
        return 'Religious or spiritual group';
      case office:
        return 'Workplace or company';
      case education:
        return 'School or educational institution';
      case family:
        return 'Family group or relatives';
      case friends:
        return 'Group of friends';
      default:
        return 'Other type of community';
    }
  }

  // Validate if a type exists
  static bool isValidType(String type) {
    return allTypes.contains(type);
  }
}
