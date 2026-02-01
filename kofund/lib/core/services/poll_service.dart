import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/polls/models/poll_model.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  CollectionReference get pollsCollection => _firestore.collection('polls');
  CollectionReference get communitiesCollection => _firestore.collection('communities');
  
  // Create a new poll
  Future<PollModel> createPoll(PollModel poll) async {
    final docRef = pollsCollection.doc(poll.pollId);
    await docRef.set(poll.toFirestore());
    return poll;
  }
  
  // Update poll
  Future<void> updatePoll(PollModel poll) async {
    await pollsCollection.doc(poll.pollId).update(poll.toFirestore());
  }
  
  // Delete poll
  Future<void> deletePoll(String pollId) async {
    await pollsCollection.doc(pollId).delete();
  }
  
  // Get poll by ID
  Future<PollModel?> getPoll(String pollId) async {
    final doc = await pollsCollection.doc(pollId).get();
    if (doc.exists) {
      return PollModel.fromFirestore(doc);
    }
    return null;
  }
  
  // Stream for individual poll by ID (for real-time updates)
  Stream<PollModel?> streamPollById(String pollId) {
    return pollsCollection
        .doc(pollId)
        .snapshots()
        .map((docSnapshot) {
          if (docSnapshot.exists) {
            return PollModel.fromFirestore(docSnapshot);
          }
          return null;
        });
  }
  
  // Get polls for a community
  Stream<List<PollModel>> streamCommunityPolls(String communityId, {String? programId}) {
    Query query = pollsCollection
      .where('communityId', isEqualTo: communityId)
      .where('status', whereIn: [PollStatus.active.index, PollStatus.closed.index])
      .orderBy('createdAt', descending: true);
    
    if (programId != null) {
      query = query.where('programId', isEqualTo: programId);
    }
    
    return query.snapshots().map((snapshot) {
      final polls = snapshot.docs
          .map((doc) => PollModel.fromFirestore(doc))
          .toList();
      
      // Remove duplicates by ID
      final uniquePolls = <PollModel>[];
      final seenIds = <String>{};
      
      for (final poll in polls) {
        if (!seenIds.contains(poll.pollId)) {
          seenIds.add(poll.pollId);
          uniquePolls.add(poll);
        }
      }
      
      return uniquePolls;
    });
  }
  
  // Get active polls for a community
  Stream<List<PollModel>> streamActivePolls(String communityId, {String? programId}) {
    Query query = pollsCollection
      .where('communityId', isEqualTo: communityId)
      .where('status', isEqualTo: PollStatus.active.index)
      .orderBy('endDate');
    
    if (programId != null) {
      query = query.where('programId', isEqualTo: programId);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PollModel.fromFirestore(doc))
          .toList();
    });
  }
  
  // UPDATED: Cast a vote with proper handling for multiple votes and vote change restrictions
  Future<void> castVote({
    required String pollId,
    required String userId,
    required String optionIndex,
    bool isMultipleVotes = false,
    bool allowVoteChange = true,
    String? oldOptionIndex,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (isMultipleVotes) {
      // For multiple votes, just add to optionVoters
      updateData['optionVoters.$optionIndex'] = FieldValue.arrayUnion([userId]);
      
      // If changing vote and vote change is allowed, remove from old option
      if (oldOptionIndex != null && oldOptionIndex != optionIndex && allowVoteChange) {
        updateData['optionVoters.$oldOptionIndex'] = FieldValue.arrayRemove([userId]);
      }
    } else {
      // For single vote, update votes map
      updateData['votes.$userId'] = optionIndex;
      updateData['optionVoters.$optionIndex'] = FieldValue.arrayUnion([userId]);
      
      // If changing vote and vote change is allowed, remove from old option
      if (oldOptionIndex != null && oldOptionIndex != optionIndex && allowVoteChange) {
        updateData['optionVoters.$oldOptionIndex'] = FieldValue.arrayRemove([userId]);
      }
    }
    
    await pollsCollection.doc(pollId).update(updateData);
  }
  
  // UPDATED: Cast vote with poll data for better decision making
  Future<void> castVoteWithPoll({
    required String pollId,
    required String userId,
    required String optionIndex,
    required bool isMultipleVotes,
    required bool allowVoteChange,
    String? oldOptionIndex,
  }) async {
    return await castVote(
      pollId: pollId,
      userId: userId,
      optionIndex: optionIndex,
      isMultipleVotes: isMultipleVotes,
      allowVoteChange: allowVoteChange,
      oldOptionIndex: oldOptionIndex,
    );
  }
  
  // UPDATED: Remove a vote with consideration for vote change restrictions
  Future<void> removeVote({
    required String pollId,
    required String userId,
    required String oldOptionIndex,
    bool isMultipleVotes = false,
    bool allowVoteChange = true,
  }) async {
    if (!allowVoteChange && !isMultipleVotes) {
      throw Exception('Vote change not allowed for this poll');
    }
    
    final updateData = <String, dynamic>{
      'optionVoters.$oldOptionIndex': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (!isMultipleVotes) {
      // For single vote, also remove from votes map
      updateData['votes.$userId'] = FieldValue.delete();
    }
    
    await pollsCollection.doc(pollId).update(updateData);
  }
  
  // NEW: Remove specific vote from multiple votes
  Future<void> removeSpecificVote({
    required String pollId,
    required String userId,
    required String optionIndex,
  }) async {
    await pollsCollection.doc(pollId).update({
      'optionVoters.$optionIndex': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Add user suggestion to poll
  Future<void> addSuggestion({
    required String pollId,
    required String suggestion,
  }) async {
    await pollsCollection.doc(pollId).update({
      'userSuggestions': FieldValue.arrayUnion([suggestion]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Change poll status
  Future<void> updatePollStatus(String pollId, PollStatus status) async {
    await pollsCollection.doc(pollId).update({
      'status': status.index,
      if (status == PollStatus.closed) 'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Get polls that need user's vote
  Stream<List<PollModel>> streamPollsNeedingVote(
    String communityId, 
    String userId, 
    {String? programId}
  ) {
    return streamActivePolls(communityId, programId: programId).map((polls) {
      return polls.where((poll) => !poll.hasUserVoted(userId)).toList();
    });
  }
  
  // NEW: Get polls where user can still vote (considering vote change restrictions)
  Stream<List<PollModel>> streamPollsUserCanVote(
    String communityId, 
    String userId, 
    {String? programId}
  ) {
    return streamActivePolls(communityId, programId: programId).map((polls) {
      return polls.where((poll) => poll.canUserVote(userId)).toList();
    });
  }
  
  // Get polls created by user
  Stream<List<PollModel>> streamUserCreatedPolls(String communityId, String userId) {
    return pollsCollection
      .where('communityId', isEqualTo: communityId)
      .where('createdBy', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => PollModel.fromFirestore(doc))
            .toList();
      });
  }
  
  // Helper method to get poll stream with specific filters
  Stream<QuerySnapshot> getPollsStream({
    required String communityId,
    PollStatus? status,
    String? programId,
    bool orderByEndDate = false,
  }) {
    Query query = pollsCollection.where('communityId', isEqualTo: communityId);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status.index);
    }
    
    if (programId != null) {
      query = query.where('programId', isEqualTo: programId);
    }
    
    if (orderByEndDate) {
      query = query.orderBy('endDate');
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    
    return query.snapshots();
  }
  
  // NEW: Update poll with allowVoteChange setting
  Future<void> updatePollVoteSettings({
    required String pollId,
    bool? allowMultipleVotes,
    bool? allowVoteChange,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (allowMultipleVotes != null) {
      updateData['allowMultipleVotes'] = allowMultipleVotes;
    }
    
    if (allowVoteChange != null) {
      updateData['allowVoteChange'] = allowVoteChange;
    }
    
    await pollsCollection.doc(pollId).update(updateData);
  }
  
  // NEW: Get poll with specific vote settings
  Future<List<PollModel>> getPollsWithVoteSettings({
    required String communityId,
    bool? allowMultipleVotes,
    bool? allowVoteChange,
    String? programId,
  }) async {
    Query query = pollsCollection.where('communityId', isEqualTo: communityId);
    
    if (allowMultipleVotes != null) {
      query = query.where('allowMultipleVotes', isEqualTo: allowMultipleVotes);
    }
    
    if (allowVoteChange != null) {
      query = query.where('allowVoteChange', isEqualTo: allowVoteChange);
    }
    
    if (programId != null) {
      query = query.where('programId', isEqualTo: programId);
    }
    
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => PollModel.fromFirestore(doc))
        .toList();
  }
  
  // NEW: Batch update votes (useful for admin actions)
  Future<void> updateMultipleVotes({
    required String pollId,
    required Map<String, String> votes,
    required Map<String, List<String>> optionVoters,
  }) async {
    await pollsCollection.doc(pollId).update({
      'votes': votes,
      'optionVoters': optionVoters,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // NEW: Get vote statistics
  Future<Map<String, dynamic>> getVoteStatistics(String pollId) async {
    final doc = await pollsCollection.doc(pollId).get();
    if (!doc.exists) {
      return {'error': 'Poll not found'};
    }
    
    final poll = PollModel.fromFirestore(doc);
    final totalVotes = poll.totalVotes;
    final totalOptionSelections = poll.totalOptionSelections;
    final optionPercentages = poll.getOptionPercentages();
    final winningOptions = poll.winningOptionIndices;
    
    return {
      'pollId': pollId,
      'totalVoters': totalVotes,
      'totalVotes': totalOptionSelections,
      'optionPercentages': optionPercentages,
      'winningOptions': winningOptions,
      'isMultipleVotes': poll.allowMultipleVotes,
      'allowVoteChange': poll.allowVoteChange,
      'averageVotesPerUser': totalVotes > 0 ? totalOptionSelections / totalVotes : 0,
    };
  }
}
