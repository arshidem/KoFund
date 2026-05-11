// lib/features/events/constants/event_filters.dart
enum StatusFilter {
  all,
  ongoing,      // eventDate.isAfter(now) && status = 'active'
  completed,    // eventDate.isBefore(now)
  cancelled,    // status = 'cancelled'
}

enum eventTypeFilter {
  all,
  general,
  football,
  trip,
  charity,
  festival,
  sports,
  meeting,
  other,
  monthly,
}

enum MonthlFilter {
  all,
  monthlyOnly,    // isMonthlyPayment = true
  regularOnly     // isMonthlyPayment = false
}

enum AvailabilityFilter {
  all,
  available,      // canJoin = true
  full,           // isFull = true
}






