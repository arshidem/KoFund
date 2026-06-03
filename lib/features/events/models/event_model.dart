import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EventModel {
  final String eventId; // Firestore document ID
  final String communityId; // Community it belongs to
  final String title; // Event title
  final String description; // Event description
  final DateTime? eventDate; // Event date (no time)
  final String location; // Venue or location
  final double? suggestedContribution; // Optional: Suggested contribution per participant
  final double? totalAmount; // Optional: Total amount needed for the event
  final int maxParticipants; // Maximum allowed participants
  final String participantType; // 'fixed' or 'unlimited'
  final String status; // active, completed, cancelled
  final String createdBy; // Admin userId
  final Timestamp createdAt; // Creation timestamp
  final int currentParticipants; // Current joined participants
  final String eventType; // e.g., football, trip, charity, etc.
  
  // 🆕 NEW FIELD: Identify if this is the monthly payment event
  final bool isMonthlyPayment;
  final List<DateTime> contributionReminderDates; // Specific dates to send reminders
  final bool enableAutoReminders; // Enable/disable automatic reminders
  final int reminderDaysBefore; // Send reminders X days before due date
  final String reminderFrequency; // 'daily', 'weekly', 'monthly', 'custom'
  final DateTime? firstPaymentDueDate; // First payment due date
  final DateTime? nextReminderDate; // When to send next reminder
  final Timestamp? updatedAt; // Last update timestamp
  final Timestamp? lastReminderSent; // When last reminder was sent
  
  // 🆕 NEW REMINDER FEATURES
  final String? customReminderTitle; 
  final String? customReminderMessage; 
  final bool enableReminderRetries; 
  final int retryDaysAfter;
  final bool enableAdminEscalation;
  final int escalationDaysAfter;

  // 🆕 PUBLIC SHARING FEATURES
  final bool isPublicEnabled;
  final String? publicPassword;

  EventModel({
    required this.eventId,
    required this.communityId,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.location,
    this.suggestedContribution,
    this.totalAmount,
    required this.maxParticipants,
    required this.participantType,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.currentParticipants = 0,
    required this.eventType,
    this.isMonthlyPayment = false, // 🆕 Default: false
    this.contributionReminderDates = const [], // 🆕
    this.enableAutoReminders = false, // 🆕
    this.reminderDaysBefore = 7, // 🆕 Default: 7 days before
    this.reminderFrequency = 'monthly', // 🆕
    this.firstPaymentDueDate, // 🆕
    this.nextReminderDate, // 🆕
    this.updatedAt, // 🆕
    this.lastReminderSent, // 🆕
    this.customReminderTitle,
    this.customReminderMessage,
    this.enableReminderRetries = false,
    this.retryDaysAfter = 3,
    this.enableAdminEscalation = false,
    this.escalationDaysAfter = 3,
    this.isPublicEnabled = false,
    this.publicPassword,
  });

  // ✅ Convert Firestore document → EventModel
// ✅ Convert Firestore document → EventModel
factory EventModel.fromMap(Map<String, dynamic> map, String documentId) {
  return EventModel(
    eventId: documentId,
    communityId: map['communityId'] ?? '',
    title: map['title'] ?? '',
    description: map['description'] ?? '',
    // ✅ Fix: Handle null eventDate from Firestore
    eventDate: map['eventDate'] != null 
        ? (map['eventDate'] as Timestamp).toDate()
        : null,
    location: map['location'] ?? '',
    suggestedContribution: map['suggestedContribution'] != null 
        ? (map['suggestedContribution'] as num).toDouble()
        : null,
    totalAmount: map['totalAmount'] != null
        ? (map['totalAmount'] as num).toDouble()
        : null,
    maxParticipants: (map['maxParticipants'] ?? 0) as int,
    participantType: map['participantType'] ?? 'fixed',
    status: map['status'] ?? 'active',
    createdBy: map['createdBy'] ?? '',
    createdAt: map['createdAt'] ?? Timestamp.now(),
    currentParticipants: (map['currentParticipants'] ?? 0) as int,
    eventType: map['eventType'] ?? 'general',
    isMonthlyPayment: map['isMonthlyPayment'] ?? false,
    contributionReminderDates: (map['contributionReminderDates'] != null)
        ? List.from(map['contributionReminderDates'])
            .map((e) => (e as Timestamp).toDate())
            .toList()
        : [],
    enableAutoReminders: map['enableAutoReminders'] ?? false,
    reminderDaysBefore: (map['reminderDaysBefore'] ?? 7) as int,
    reminderFrequency: map['reminderFrequency'] ?? 'monthly',
    firstPaymentDueDate: map['firstPaymentDueDate'] != null 
        ? (map['firstPaymentDueDate'] as Timestamp).toDate()
        : null,
    nextReminderDate: map['nextReminderDate'] != null 
        ? (map['nextReminderDate'] as Timestamp).toDate()
        : null,
    updatedAt: map['updatedAt'] as Timestamp?,
    lastReminderSent: map['lastReminderSent'] as Timestamp?,
    customReminderTitle: map['customReminderTitle'] as String?,
    customReminderMessage: map['customReminderMessage'] as String?,
    enableReminderRetries: map['enableReminderRetries'] ?? false,
    retryDaysAfter: (map['retryDaysAfter'] ?? 3) as int,
    enableAdminEscalation: map['enableAdminEscalation'] ?? false,
    escalationDaysAfter: (map['escalationDaysAfter'] ?? 3) as int,
    isPublicEnabled: map['isPublicEnabled'] ?? false,
    publicPassword: map['publicPassword'] as String?,
  );
}

  // ✅ Convert EventModel → Firestore document
// ✅ Convert EventModel → Firestore document
Map<String, dynamic> toMap() {
  return {
    'communityId': communityId,
    'title': title,
    'description': description,
    // ✅ Fix: Handle null eventDate for monthly events
    'eventDate': eventDate != null 
        ? Timestamp.fromDate(_stripTime(eventDate!))
        : null,
    'location': location,
    'suggestedContribution': suggestedContribution,
    'totalAmount': totalAmount,
    'maxParticipants': maxParticipants,
    'participantType': participantType,
    'status': status,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'currentParticipants': currentParticipants,
    'eventType': eventType,
    'isMonthlyPayment': isMonthlyPayment,
    'contributionReminderDates': contributionReminderDates
        .map((date) => Timestamp.fromDate(date))
        .toList(),
    'enableAutoReminders': enableAutoReminders,
    'reminderDaysBefore': reminderDaysBefore,
    'reminderFrequency': reminderFrequency,
    'firstPaymentDueDate': firstPaymentDueDate != null 
        ? Timestamp.fromDate(firstPaymentDueDate!)
        : null,
    'nextReminderDate': nextReminderDate != null 
        ? Timestamp.fromDate(nextReminderDate!)
        : null,
    'updatedAt': updatedAt ?? Timestamp.now(),
    if (customReminderTitle != null) 'customReminderTitle': customReminderTitle,
    if (customReminderMessage != null) 'customReminderMessage': customReminderMessage,
    'enableReminderRetries': enableReminderRetries,
    'retryDaysAfter': retryDaysAfter,
    'enableAdminEscalation': enableAdminEscalation,
    'escalationDaysAfter': escalationDaysAfter,
    'isPublicEnabled': isPublicEnabled,
    'publicPassword': publicPassword,
  };
}

  // ✅ copyWith method (updated)
  EventModel copyWith({
    String? eventId,
    String? communityId,
    String? title,
    String? description,
    DateTime? eventDate,
    String? location,
    double? suggestedContribution,
    double? totalAmount,
    int? maxParticipants,
    String? participantType,
    String? status,
    String? createdBy,
    Timestamp? createdAt,
    int? currentParticipants,
    String? eventType,
    bool? isMonthlyPayment,
    List<DateTime>? contributionReminderDates,
    bool? enableAutoReminders,
    int? reminderDaysBefore,
    String? reminderFrequency,
    DateTime? firstPaymentDueDate,
    DateTime? nextReminderDate,
    Timestamp? updatedAt,
    Timestamp? lastReminderSent,
    String? customReminderTitle,
    String? customReminderMessage,
    bool? enableReminderRetries,
    int? retryDaysAfter,
    bool? enableAdminEscalation,
    int? escalationDaysAfter,
    bool? isPublicEnabled,
    String? publicPassword,
    bool clearPassword = false,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      suggestedContribution: suggestedContribution ?? this.suggestedContribution,
      totalAmount: totalAmount ?? this.totalAmount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participantType: participantType ?? this.participantType,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      eventType: eventType ?? this.eventType,
      isMonthlyPayment: isMonthlyPayment ?? this.isMonthlyPayment,
      contributionReminderDates: contributionReminderDates ?? this.contributionReminderDates,
      enableAutoReminders: enableAutoReminders ?? this.enableAutoReminders,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      firstPaymentDueDate: firstPaymentDueDate ?? this.firstPaymentDueDate,
      nextReminderDate: nextReminderDate ?? this.nextReminderDate,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReminderSent: lastReminderSent ?? this.lastReminderSent,
      customReminderTitle: customReminderTitle ?? this.customReminderTitle,
      customReminderMessage: customReminderMessage ?? this.customReminderMessage,
      enableReminderRetries: enableReminderRetries ?? this.enableReminderRetries,
      retryDaysAfter: retryDaysAfter ?? this.retryDaysAfter,
      enableAdminEscalation: enableAdminEscalation ?? this.enableAdminEscalation,
      escalationDaysAfter: escalationDaysAfter ?? this.escalationDaysAfter,
      isPublicEnabled: isPublicEnabled ?? this.isPublicEnabled,
      publicPassword: clearPassword ? null : (publicPassword ?? this.publicPassword),
    );
  }

  // ✅ NEW: Check if this is the monthly payment event
  bool get isCommunityMonthly => isMonthlyPayment;

  // ✅ Calculate estimated total amount
  double get estimatedTotalAamount {
    if (totalAmount != null) {
      return totalAmount!;
    }
    if (suggestedContribution != null && maxParticipants > 0) {
      return suggestedContribution! * maxParticipants;
    }
    return 0.0;
  }

  bool get hasFinancialGoals => suggestedContribution != null || totalAmount != null;

  // ✅ Calculate progress percentage
  double calculateProgress(double totalCollected) {
    if (totalAmount != null && totalAmount! > 0) {
      return (totalCollected / totalAmount!) * 100;
    }
    if (suggestedContribution != null && currentParticipants > 0) {
      final estimatedTotal = suggestedContribution! * currentParticipants;
      return estimatedTotal > 0 ? (totalCollected / estimatedTotal) * 100 : 0;
    }
    return 0.0;
  }

  double get effectiveSuggestedContribution {
    return suggestedContribution ?? 0.0;
  }

  // ✅ Participant type checks
  bool get isFixedParticipants => participantType == 'fixed';
  bool get isUnlimitedParticipants => participantType == 'unlimited';
  bool get isFull => isFixedParticipants && currentParticipants >= maxParticipants;
  bool get canJoin => isUnlimitedParticipants || !isFull;

  int get availableSpots {
    if (isUnlimitedParticipants) return 999;
    return maxParticipants - currentParticipants;
  }

// ✅ Status checks - FIXED VERSION
bool get isOngoing => status == 'active';  // All active events are ongoing
bool get isCompleted => status == 'completed';  // Only explicitly completed
bool get isCancelled => status == 'cancelled';
bool get isActive => status == 'active';

// ✅ Computed status that automatically updates based on event date
// ✅ Computed status that automatically updates based on event date
String get computedStatus {
  // For monthly payment events, always return 'active'
  if (isMonthlyPayment) {
    return 'active';
  }
  // If manually set to cancelled or completed, keep that
  if (status == 'cancelled' || status == 'completed') {
    return status;
  }
  // Only check date if eventDate is not null
  if (eventDate != null) {
    final now = DateTime.now();
    final dateOnly = DateTime(eventDate!.year, eventDate!.month, eventDate!.day);
    final nowOnly = DateTime(now.year, now.month, now.day);
    final isDatePassed = dateOnly.isBefore(nowOnly);
    if (isDatePassed) {
      return 'completed';
    }
  }
  // Otherwise return the original status
  return status;
}
// Update status only when event is loaded/viewed
Future<void> syncComputedStatusToFirestore() async {
  if (computedStatus != status) {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .update({
      'status': computedStatus,
      'updatedAt': Timestamp.now(),
    });
  }
}
// Add this new getter for date-based display
// Update these getters to handle null
bool get isDatePast => eventDate != null ? eventDate!.isBefore(DateTime.now()) : false;
bool get isDateFuture => eventDate != null ? eventDate!.isAfter(DateTime.now()) : false;
  // ✅ Helper method to strip time from DateTime
  static DateTime _stripTime(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // ✅ Check if should send reminder (Helper for compatibility/fallback)
  bool shouldSendReminder(DateTime currentDate) {
    if (!enableAutoReminders || nextReminderDate == null) return false;
    // We only rely on nextReminderDate falling behind the current time
    // If it's less than now, it's pending to be sent.
    return nextReminderDate!.isBefore(currentDate);
  }

  // ✅ Get next upcoming reminder date
  DateTime? get nextUpcomingReminder => nextReminderDate;

  // ✅ Calculate next reminder date based on frequency and lead time
  DateTime? calculateNextReminderDate() {
    if (!enableAutoReminders) return null;
    
    final now = DateTime.now();
    final candidateSendDates = <DateTime>[];
    
    // 1. Literal Custom Send Dates
    if (contributionReminderDates.isNotEmpty) {
      for (final date in contributionReminderDates) {
        if (date.isAfter(now)) {
          candidateSendDates.add(date);
        }
      }
    }
    
    // 2. Frequency-based Due Dates -> Send Dates
    if (firstPaymentDueDate != null) {
      DateTime currentDueDate = firstPaymentDueDate!;
      int safeguard = 0;
      
      // Look ahead up to 24 cycles to find the next valid future send date
      while (safeguard < 24) {
        safeguard++;
        final sendDate = currentDueDate.subtract(Duration(days: reminderDaysBefore));
        
        if (sendDate.isAfter(now)) {
          candidateSendDates.add(sendDate);
          break; // Found the next immediate one, no need to look further for this pattern
        }
        
        switch (reminderFrequency) {
          case 'daily':
            currentDueDate = currentDueDate.add(const Duration(days: 1));
            break;
          case 'weekly':
            currentDueDate = currentDueDate.add(const Duration(days: 7));
            break;
          case 'monthly':
            currentDueDate = DateTime(currentDueDate.year, currentDueDate.month + 1, currentDueDate.day);
            break;
          case 'custom':
          default:
            safeguard = 24; // Break loop for custom/invalid frequencies
            break;
        }
      }
    }
    
    if (candidateSendDates.isEmpty) return null;
    
    candidateSendDates.sort();
    return candidateSendDates.first;
  }

  // ✅ Check if any reminders are scheduled
  bool get hasScheduledReminders {
    if (!enableAutoReminders) return false;
    return contributionReminderDates.isNotEmpty || firstPaymentDueDate != null;
  }

  // ✅ Get list of all upcoming reminder dates
  List<DateTime> get upcomingReminderDates {
    if (!enableAutoReminders) return [];
    
    final now = DateTime.now();
    final upcoming = <DateTime>[];
    
    // Add specific reminder dates that are in the future
    for (final date in contributionReminderDates) {
      if (date.isAfter(now)) {
        upcoming.add(date);
      }
    }
    
    // Add first payment due date if in the future
    if (firstPaymentDueDate != null && firstPaymentDueDate!.isAfter(now)) {
      upcoming.add(firstPaymentDueDate!);
    }
    
    // Sort by date
    upcoming.sort();
    return upcoming;
  }

  @override
  String toString() {
    return 'EventModel(eventId: $eventId, title: $title, status: $status, '
           'isMonthlyPayment: $isMonthlyPayment, '
           'enableAutoReminders: $enableAutoReminders, '
           'contributionReminderDates: ${contributionReminderDates.length} dates, '
           'participants: $currentParticipants/$maxParticipants, '
           'suggested: $suggestedContribution, total: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is EventModel &&
        other.eventId == eventId &&
        other.communityId == communityId &&
        other.title == title &&
        other.description == description &&
        other.eventDate == eventDate &&
        other.location == location &&
        other.suggestedContribution == suggestedContribution &&
        other.totalAmount == totalAmount &&
        other.maxParticipants == maxParticipants &&
        other.participantType == participantType &&
        other.status == status &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.currentParticipants == currentParticipants &&
        other.eventType == eventType &&
        other.isMonthlyPayment == isMonthlyPayment &&
        listEquals(other.contributionReminderDates, contributionReminderDates) &&
        other.enableAutoReminders == enableAutoReminders &&
        other.reminderDaysBefore == reminderDaysBefore &&
        other.reminderFrequency == reminderFrequency &&
        other.firstPaymentDueDate == firstPaymentDueDate &&
        other.nextReminderDate == nextReminderDate &&
        other.customReminderTitle == customReminderTitle &&
        other.customReminderMessage == customReminderMessage &&
        other.enableReminderRetries == enableReminderRetries &&
        other.retryDaysAfter == retryDaysAfter &&
        other.enableAdminEscalation == enableAdminEscalation &&
        other.escalationDaysAfter == escalationDaysAfter &&
        other.isPublicEnabled == isPublicEnabled &&
        other.publicPassword == publicPassword;
  }

@override
int get hashCode {
  return Object.hashAll([
    eventId,
    communityId,
    title,
    description,
    eventDate,
    location,
    suggestedContribution,
    totalAmount,
    maxParticipants,
    participantType,
    status,
    createdBy,
    createdAt,
    currentParticipants,
    eventType,
    isMonthlyPayment,
    Object.hashAll(contributionReminderDates),
    enableAutoReminders,
    reminderDaysBefore,
    reminderFrequency,
    firstPaymentDueDate,
    nextReminderDate,
    customReminderTitle,
    customReminderMessage,
    enableReminderRetries,
    retryDaysAfter,
    enableAdminEscalation,
    escalationDaysAfter,
    isPublicEnabled,
    publicPassword,
  ]);
}
}






