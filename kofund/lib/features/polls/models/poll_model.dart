import 'package:cloud_firestore/cloud_firestore.dart';

enum PollType {
  decision,
  suggestion,
  planning,
  contribution,
  expenseApproval,
}

enum PollStatus {
  active,
  closed,
  archived,
}

class PollModel {
  final String pollId;
  final String communityId;
  final String? programId;
  final String title;
  final String description;
  final PollType type;
  final PollStatus status;
  
  final List<String> options;
  final bool isAnonymous;
  final bool allowMultipleVotes;
  final bool allowVoteChange; // NEW: Control if votes can be changed
  final int? minParticipationPercent;
  final DateTime endDate;
  
  // Votes data
  final Map<String, String> votes;
  final Map<String, List<String>> optionVoters;
  
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  
  // Implementation data
  final bool isImplemented;
  final DateTime? implementedAt;
  final Map<String, dynamic>? resultData;

  PollModel({
    required this.pollId,
    required this.communityId,
    this.programId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.options,
    required this.isAnonymous,
    this.allowMultipleVotes = false,
    this.allowVoteChange = true, // NEW: Default to true (can change votes)
    this.minParticipationPercent,
    required this.endDate,
    required this.votes,
    required this.optionVoters,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.isImplemented = false,
    this.implementedAt,
    this.resultData,
  });

  // Factory constructor from Firestore document
  factory PollModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PollModel(
      pollId: doc.id,
      communityId: data['communityId'] as String,
      programId: data['programId'] as String?,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      type: PollType.values[data['type'] as int? ?? 0],
      status: PollStatus.values[data['status'] as int? ?? 0],
      options: List<String>.from(data['options'] as List? ?? []),
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      allowMultipleVotes: data['allowMultipleVotes'] as bool? ?? false,
      allowVoteChange: data['allowVoteChange'] as bool? ?? true, // NEW: Default to true
      minParticipationPercent: data['minParticipationPercent'] as int?,
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      votes: Map<String, String>.from(data['votes'] as Map? ?? {}),
      optionVoters: _parseOptionVoters(data['optionVoters']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isImplemented: data['isImplemented'] as bool? ?? false,
      implementedAt: (data['implementedAt'] as Timestamp?)?.toDate(),
      resultData: data['resultData'] as Map<String, dynamic>?,
    );
  }

  static Map<String, List<String>> _parseOptionVoters(dynamic votersData) {
    final result = <String, List<String>>{};
    
    if (votersData is Map) {
      votersData.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = List<String>.from(value.map((e) => e.toString()));
        }
      });
    }
    
    return result;
  }

  // Check if poll is expired
  bool get isExpired => DateTime.now().isAfter(endDate);
  
  // Check if user has voted
  bool hasUserVoted(String userId) {
    return votes.containsKey(userId);
  }
  
  // Get user's vote - handles multiple votes
  String? getUserVote(String userId) {
    return votes[userId];
  }
  
  // Check if user has voted for specific option (for multiple votes)
  bool hasUserVotedForOption(String userId, String optionIndex) {
    return optionVoters[optionIndex]?.contains(userId) ?? false;
  }
  
  // Get all options user has voted for (for multiple votes)
  List<String> getUserVotes(String userId) {
    final userVotes = <String>[];
    for (final entry in optionVoters.entries) {
      if (entry.value.contains(userId)) {
        userVotes.add(entry.key);
      }
    }
    return userVotes;
  }
  
  // Check if user can change their vote
  bool canUserChangeVote(String userId) {
    // User can change vote if:
    // 1. Poll allows vote changes, OR
    // 2. User hasn't voted yet, OR
    // 3. Poll allows multiple votes (changing is essentially adding/removing)
    return allowVoteChange || !hasUserVoted(userId) || allowMultipleVotes;
  }
  
  // Get vote count for an option
  int getOptionVoteCount(String optionIndex) {
    return optionVoters[optionIndex]?.length ?? 0;
  }
  
  // Get total votes (unique voters)
  int get totalVotes {
    return votes.length;
  }
  
  // Get total votes across all options (for multiple votes scenario)
  int get totalOptionSelections {
    int total = 0;
    for (final voters in optionVoters.values) {
      total += voters.length;
    }
    return total;
  }
  
  // Get option percentages
  Map<String, double> getOptionPercentages() {
    final percentages = <String, double>{};
    final total = totalOptionSelections; // Use total selections for percentage calculation
    
    for (var i = 0; i < options.length; i++) {
      final index = i.toString();
      final count = getOptionVoteCount(index);
      percentages[index] = total > 0 ? (count / total * 100) : 0.0;
    }
    
    return percentages;
  }
  
  // Get winning option(s) - returns list in case of ties
  List<String> get winningOptionIndices {
    if (totalOptionSelections == 0) return [];
    
    final List<String> winningIndices = [];
    int maxVotes = 0;
    
    for (var i = 0; i < options.length; i++) {
      final index = i.toString();
      final count = getOptionVoteCount(index);
      
      if (count > maxVotes) {
        maxVotes = count;
        winningIndices.clear();
        winningIndices.add(index);
      } else if (count == maxVotes && count > 0) {
        winningIndices.add(index);
      }
    }
    
    return winningIndices;
  }
  
  // Convenience getter for single winner (for backward compatibility)
  String? get winningOptionIndex {
    final winners = winningOptionIndices;
    return winners.isNotEmpty ? winners.first : null;
  }
  
  factory PollModel.empty() {
    return PollModel(
      pollId: '',
      communityId: '',
      title: '',
      description: '',
      type: PollType.decision,
      status: PollStatus.active,
      options: [],
      isAnonymous: false,
      allowMultipleVotes: false,
      allowVoteChange: true, // NEW
      endDate: DateTime.now(),
      votes: {},
      optionVoters: {},
      createdAt: DateTime.now(),
      createdBy: '',
      updatedAt: null,
      isImplemented: false,
    );
  }

  // CopyWith method
  PollModel copyWith({
    String? pollId,
    String? communityId,
    String? programId,
    String? title,
    String? description,
    PollType? type,
    PollStatus? status,
    List<String>? options,
    bool? isAnonymous,
    bool? allowMultipleVotes,
    bool? allowVoteChange, // NEW
    int? minParticipationPercent,
    DateTime? endDate,
    Map<String, String>? votes,
    Map<String, List<String>>? optionVoters,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    bool? isImplemented,
    DateTime? implementedAt,
    Map<String, dynamic>? resultData,
  }) {
    return PollModel(
      pollId: pollId ?? this.pollId,
      communityId: communityId ?? this.communityId,
      programId: programId ?? this.programId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      options: options ?? this.options,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      allowMultipleVotes: allowMultipleVotes ?? this.allowMultipleVotes,
      allowVoteChange: allowVoteChange ?? this.allowVoteChange, // NEW
      minParticipationPercent: minParticipationPercent ?? this.minParticipationPercent,
      endDate: endDate ?? this.endDate,
      votes: votes ?? this.votes,
      optionVoters: optionVoters ?? this.optionVoters,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      isImplemented: isImplemented ?? this.isImplemented,
      implementedAt: implementedAt ?? this.implementedAt,
      resultData: resultData ?? this.resultData,
    );
  }
  
  // Convert to map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'communityId': communityId,
      'programId': programId,
      'title': title,
      'description': description,
      'type': type.index,
      'status': status.index,
      'options': options,
      'isAnonymous': isAnonymous,
      'allowMultipleVotes': allowMultipleVotes,
      'allowVoteChange': allowVoteChange, // NEW
      'minParticipationPercent': minParticipationPercent,
      'endDate': Timestamp.fromDate(endDate),
      'votes': votes,
      'optionVoters': optionVoters,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isImplemented': isImplemented,
      if (implementedAt != null) 'implementedAt': Timestamp.fromDate(implementedAt!),
      if (resultData != null) 'resultData': resultData,
    };
  }

  // Helper method to get poll configuration summary
  String get configurationSummary {
    final List<String> configs = [];
    
    if (isAnonymous) configs.add('Anonymous');
    if (allowMultipleVotes) configs.add('Multiple votes');
    if (!allowVoteChange) configs.add('Votes locked');
    if (minParticipationPercent != null) {
      configs.add('$minParticipationPercent% min participation');
    }
    
    return configs.join(' • ');
  }

  // Helper method to check if user can vote
  bool canUserVote(String userId) {
    // User can vote if:
    // 1. Poll is active and not expired
    // 2. User hasn't voted OR poll allows multiple votes OR poll allows vote changes
    return status == PollStatus.active && 
           !isExpired &&
           (!hasUserVoted(userId) || allowMultipleVotes || allowVoteChange);
  }
}
