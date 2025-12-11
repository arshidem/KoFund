// kofund/lib/features/polls/constants/poll_constants.dart
class PollConstants {
  static const List<String> pollTypeLabels = [
    'Decision',
    'Suggestion', 
    'Planning',
    'Contribution',
    'Expense Approval',
  ];

  static const List<String> pollTypeDescriptions = [
    'Make community decisions',
    'Gather ideas and suggestions',
    'Plan schedules and dates',
    'Decide financial matters',
    'Approve large expenses',
  ];

  static const List<String> visibilityLabels = [
    'Anonymous Voting',
    'Visible to All',
    'Visible After Voting',
  ];

  static const List<String> visibilityDescriptions = [
    'Votes are anonymous',
    'Everyone can see who voted for what',
    'Results visible only after voting',
  ];
}