// lib/features/programs/constants/program_filters.dart
enum ProgramStatusFilter {
  all,
  ongoing,      // programDate.isAfter(now) && status = 'active'
  completed,    // programDate.isBefore(now)
  cancelled,    // status = 'cancelled'
}

enum ProgramTypeFilter {
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

enum MonthlyProgramFilter {
  all,
  monthlyOnly,    // isMonthlyPaymentProgram = true
  regularOnly     // isMonthlyPaymentProgram = false
}

enum AvailabilityFilter {
  all,
  available,      // canJoin = true
  full,           // isFull = true
}
