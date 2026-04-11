enum NotificationType {
  payment,
  programUpdate,
  adminAlert,
  system,
  announcement,
  reminder,
  approval,
  withdrawal,
  account,
  community,
  contribution,
  program,
  pendingUser,
}

enum NotificationPriority {
  critical,   // Red - Urgent alerts
  high,       // Orange - Important updates
  normal,     // Blue - Regular notifications
  low,        // Gray - Informational
}
