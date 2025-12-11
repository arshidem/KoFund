class CommunityType {
  // Community Type Constants
  static const String apartment = 'Apartment';
  static const String residential = 'Residential Society';
  static const String club = 'Club';
  static const String sports = 'Sports Club';
  static const String temple = 'Temple';
  static const String religious = 'Religious Group';
  static const String office = 'Office';
  static const String college = 'College';
  static const String school = 'School';
  static const String family = 'Family';
  static const String friends = 'Friends Group';
  static const String neighborhood = 'Neighborhood';
  static const String hobby = 'Hobby Group';
  static const String charity = 'Charity';
  static const String other = 'Other';
  
  // Get all types as list
  static List<String> get allTypes => [
    apartment,
    residential,
    club,
    sports,
    temple,
    religious,
    office,
    college,
    school,
    family,
    friends,
    neighborhood,
    hobby,
    charity,
    other,
  ];
  
  // Get icons for each type (for UI)
  static String getIcon(String type) {
    switch (type) {
      case apartment:
      case residential:
        return '🏢';
      case club:
        return '🎯';
      case sports:
        return '⚽';
      case temple:
      case religious:
        return '🛕';
      case office:
        return '💼';
      case college:
      case school:
        return '🎓';
      case family:
        return '👨‍👩‍👧‍👦';
      case friends:
        return '👥';
      case neighborhood:
        return '🏘️';
      case hobby:
        return '🎨';
      case charity:
        return '🤝';
      default:
        return '🏠';
    }
  }
  
  // Get description for each type (optional)
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
      case temple:
        return 'Religious place of worship';
      case religious:
        return 'Religious or spiritual group';
      case office:
        return 'Workplace or company';
      case college:
        return 'College or university';
      case school:
        return 'School or educational institution';
      case family:
        return 'Family group or relatives';
      case friends:
        return 'Group of friends';
      case neighborhood:
        return 'Local neighborhood community';
      case hobby:
        return 'Hobby or interest group';
      case charity:
        return 'Charity or non-profit organization';
      default:
        return 'Other type of community';
    }
  }
  
  // Validate if a type exists
  static bool isValidType(String type) {
    return allTypes.contains(type);
  }
}