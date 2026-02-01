import 'package:flutter/foundation.dart';
import 'package:kofund/features/polls/models/poll_model.dart';
import 'package:kofund/core/services/poll_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class PollProvider with ChangeNotifier {
  final PollService _pollService = PollService();
  
  List<PollModel> _polls = [];
  List<PollModel> _activePolls = [];
  List<PollModel> _pollsNeedingVote = [];
  bool _isLoading = false;
  String? _error;
  
  // Stream subscriptions for cleanup
  StreamSubscription<List<PollModel>>? _pollsSubscription;
  StreamSubscription<List<PollModel>>? _activePollsSubscription;
  StreamSubscription<List<PollModel>>? _needingVoteSubscription;
  
  // Poll cache for quick access
  final Map<String, PollModel> _pollCache = {};
  
  // Getters
  List<PollModel> get polls => List.unmodifiable(_polls);
  List<PollModel> get activePolls => List.unmodifiable(_activePolls);
  List<PollModel> get pollsNeedingVote => List.unmodifiable(_pollsNeedingVote);
  bool get isLoading => _isLoading;
  String? get error => _error;
  PollService get pollService => _pollService;
  
  // Get specific poll by ID - for real-time updates
  PollModel? getPollById(String pollId) {
    // First check cache
    if (_pollCache.containsKey(pollId)) {
      return _pollCache[pollId];
    }
    
    // Safer approach without exceptions
    PollModel? findPollInList(List<PollModel> list) {
      for (var poll in list) {
        if (poll.pollId == pollId) {
          return poll;
        }
      }
      return null;
    }
    
    PollModel? poll = findPollInList(_polls);
    poll ??= findPollInList(_activePolls);
    poll ??= findPollInList(_pollsNeedingVote);
    
    if (poll != null) {
      _pollCache[pollId] = poll;
      return poll;
    }
    
    return null;
  }
  
  // Load all polls for community
  Future<void> loadCommunityPolls(String communityId, {String? programId}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Cancel existing subscriptions
      await _pollsSubscription?.cancel();
      await _activePollsSubscription?.cancel();
      
      // Set up stream listeners for real-time updates
      _pollsSubscription = _pollService
          .streamCommunityPolls(communityId, programId: programId)
          .listen(_updatePollsList, onError: _handleStreamError);
      
      _activePollsSubscription = _pollService
          .streamActivePolls(communityId, programId: programId)
          .listen(_updateActivePollsList, onError: _handleStreamError);
      
      _isLoading = false;
      notifyListeners();
      
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading polls: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Helper method to update polls list and cache
  void _updatePollsList(List<PollModel> polls) {
    _polls = polls;
    
    // Update cache
    for (var poll in polls) {
      _pollCache[poll.pollId] = poll;
    }
    
    // Only notify if not already loading
    if (!_isLoading) {
      notifyListeners();
    }
  }
  
  // Helper method to update active polls list
  void _updateActivePollsList(List<PollModel> polls) {
    _activePolls = polls;
    
    // Update cache
    for (var poll in polls) {
      _pollCache[poll.pollId] = poll;
    }
    
    // Only notify if not already loading
    if (!_isLoading) {
      notifyListeners();
    }
  }
  
  // Stream error handler
  void _handleStreamError(error) {
    _error = error.toString();
    debugPrint('Stream error in PollProvider: $error');
    _isLoading = false;
    notifyListeners();
  }
  
  // Load polls needing user's vote
  Future<void> loadPollsNeedingVote(String communityId, String userId) async {
    try {
      // Cancel existing subscription
      await _needingVoteSubscription?.cancel();
      
      _needingVoteSubscription = _pollService
          .streamPollsNeedingVote(communityId, userId)
          .listen(_updatePollsNeedingVoteList);
      
    } catch (e) {
      debugPrint('Error loading polls needing vote: $e');
    }
  }
  
  void _updatePollsNeedingVoteList(List<PollModel> polls) {
    _pollsNeedingVote = polls;
    
    // Update cache
    for (var poll in polls) {
      _pollCache[poll.pollId] = poll;
    }
    
    notifyListeners();
  }
  
  // Get individual poll - useful for real-time updates
  Future<PollModel?> getPoll(String pollId) async {
    try {
      // Check cache first
      if (_pollCache.containsKey(pollId)) {
        return _pollCache[pollId];
      }
      
      final poll = await _pollService.getPoll(pollId);
      
      if (poll != null) {
        _pollCache[pollId] = poll;
      }
      
      return poll;
    } catch (e) {
      debugPrint('Error getting poll: $e');
      return null;
    }
  }
  
  // Create poll - UPDATED with allowVoteChange parameter
  Future<PollModel?> createPoll({
    required String communityId,
    String? programId,
    required String title,
    required String description,
    required PollType type,
    required List<String> options,
    required DateTime endDate,
    required String createdBy,
    bool allowMultipleVotes = false,
    bool allowVoteChange = true, // NEW: Default to true
    bool isAnonymous = false,
    int? minParticipationPercent,
    bool requireAdminApproval = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final pollId = _pollService.pollsCollection.doc().id;
      final now = DateTime.now();
      
      final poll = PollModel(
        pollId: pollId,
        communityId: communityId,
        programId: programId,
        title: title,
        description: description,
        type: type,
        status: PollStatus.active,
        options: options,
        isAnonymous: isAnonymous,
        allowMultipleVotes: allowMultipleVotes,
        allowVoteChange: allowVoteChange, // NEW
        endDate: endDate,
        votes: {},
        optionVoters: {},
        createdAt: now,
        createdBy: createdBy,
        updatedAt: now,
        minParticipationPercent: minParticipationPercent,
      );
      
      await _pollService.createPoll(poll);
      
      // Add to local cache immediately
      _pollCache[pollId] = poll;
      
      return poll;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating poll: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // UPDATED: Instagram-style instant voting with vote change restriction check
  Future<bool> castVote({
    required String pollId,
    required String userId,
    required String optionIndex,
  }) async {
    try {
      // Get current poll
      final currentPoll = getPollById(pollId);
      if (currentPoll == null) {
        debugPrint('Poll not found: $pollId');
        return false;
      }
      
      // Check if user can vote
      if (!currentPoll.canUserVote(userId)) {
        debugPrint('User $userId cannot vote on poll $pollId');
        return false;
      }
      
      final hasVoted = currentPoll.hasUserVoted(userId);
      final currentUserVote = currentPoll.getUserVote(userId);
      
      // Check if vote change is allowed
      if (hasVoted && !currentPoll.allowVoteChange && !currentPoll.allowMultipleVotes) {
        debugPrint('Vote change not allowed for poll $pollId');
        return false;
      }
      
      // If already voted for this option and it's not multiple votes, do nothing
      if (hasVoted && currentUserVote == optionIndex && !currentPoll.allowMultipleVotes) {
        return true;
      }
      
      // Prepare update data
      final updateData = <String, dynamic>{
        'optionVoters.$optionIndex': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Handle different voting scenarios
      if (currentPoll.allowMultipleVotes) {
        // For multiple votes, we don't overwrite the votes map
        // Just add to optionVoters for this specific option
        // User might need to remove vote from other option if changing
        if (hasVoted && !currentPoll.allowVoteChange) {
          // Check if user already voted for this option in multiple votes
          if (currentPoll.hasUserVotedForOption(userId, optionIndex)) {
            return true; // Already voted for this option
          }
        }
      } else {
        // For single vote, update votes map
        updateData['votes.$userId'] = optionIndex;
        
        // If changing vote and not allowing multiple votes, remove old vote
        if (hasVoted && currentUserVote != null && currentUserVote != optionIndex) {
          updateData['optionVoters.$currentUserVote'] = FieldValue.arrayRemove([userId]);
        }
      }
      
      // Update Firestore
      await _pollService.pollsCollection.doc(pollId).update(updateData);
      
      // Immediately update local cache for instant UI response
      final updatedPoll = _updateLocalPollAfterVote(
        currentPoll,
        userId,
        optionIndex,
        hasVoted,
        currentUserVote,
      );
      
      _pollCache[pollId] = updatedPoll;
      _updatePollInLocalLists(updatedPoll);
      
      return true;
    } catch (e) {
      debugPrint('Error casting vote: $e');
      return false;
    }
  }
  
  // Helper to update local poll after vote
  PollModel _updateLocalPollAfterVote(
    PollModel currentPoll,
    String userId,
    String newOptionIndex,
    bool hasVoted,
    String? oldOptionIndex,
  ) {
    // Handle multiple votes scenario
    if (currentPoll.allowMultipleVotes) {
      final updatedOptionVoters = Map<String, List<String>>.from(currentPoll.optionVoters);
      
      // Add to new option
      if (!updatedOptionVoters.containsKey(newOptionIndex)) {
        updatedOptionVoters[newOptionIndex] = [];
      }
      if (!updatedOptionVoters[newOptionIndex]!.contains(userId)) {
        updatedOptionVoters[newOptionIndex] = [...updatedOptionVoters[newOptionIndex]!, userId];
      }
      
      // For multiple votes with vote change not allowed, we keep all votes
      // For vote change allowed, we might remove from old option
      if (hasVoted && 
          oldOptionIndex != null && 
          oldOptionIndex != newOptionIndex &&
          currentPoll.allowVoteChange) {
        // Remove from old option if changing
        if (updatedOptionVoters.containsKey(oldOptionIndex)) {
          updatedOptionVoters[oldOptionIndex] = updatedOptionVoters[oldOptionIndex]!
              .where((id) => id != userId)
              .toList();
              
          if (updatedOptionVoters[oldOptionIndex]!.isEmpty) {
            updatedOptionVoters.remove(oldOptionIndex);
          }
        }
      }
      
      return currentPoll.copyWith(
        optionVoters: updatedOptionVoters,
        updatedAt: DateTime.now(),
      );
    } else {
      // Single vote scenario
      final updatedVotes = Map<String, String>.from(currentPoll.votes);
      updatedVotes[userId] = newOptionIndex;
      
      final updatedOptionVoters = _updateOptionVoters(
        currentPoll.optionVoters,
        newOptionIndex,
        userId,
        oldOptionIndex: hasVoted ? oldOptionIndex : null,
        allowMultipleVotes: false,
      );
      
      return currentPoll.copyWith(
        votes: updatedVotes,
        optionVoters: updatedOptionVoters,
        updatedAt: DateTime.now(),
      );
    }
  }
  
  // Helper to update optionVoters map
  Map<String, List<String>> _updateOptionVoters(
    Map<String, List<String>> optionVoters,
    String newOptionIndex,
    String userId,
    {String? oldOptionIndex,
    bool allowMultipleVotes = false}
  ) {
    final updatedVoters = Map<String, List<String>>.from(optionVoters);
    
    // Add user to new option
    if (!updatedVoters.containsKey(newOptionIndex)) {
      updatedVoters[newOptionIndex] = [];
    }
    if (!updatedVoters[newOptionIndex]!.contains(userId)) {
      updatedVoters[newOptionIndex] = [...updatedVoters[newOptionIndex]!, userId];
    }
    
    // Remove from old option if not allowing multiple votes
    if (oldOptionIndex != null && 
        updatedVoters.containsKey(oldOptionIndex) &&
        !allowMultipleVotes) {
      updatedVoters[oldOptionIndex] = updatedVoters[oldOptionIndex]!
          .where((id) => id != userId)
          .toList();
          
      // Remove empty option
      if (updatedVoters[oldOptionIndex]!.isEmpty) {
        updatedVoters.remove(oldOptionIndex);
      }
    }
    
    return updatedVoters;
  }
  
  // UPDATED: Remove vote with vote change restriction check
  Future<bool> removeVote({
    required String pollId,
    required String userId,
    required String oldOptionIndex,
  }) async {
    try {
      final currentPoll = getPollById(pollId);
      if (currentPoll == null) return false;
      
      // Check if vote change is allowed
      if (!currentPoll.allowVoteChange && !currentPoll.allowMultipleVotes) {
        debugPrint('Cannot remove vote: vote change not allowed');
        return false;
      }
      
      await _pollService.pollsCollection.doc(pollId).update({
        if (!currentPoll.allowMultipleVotes) 'votes.$userId': FieldValue.delete(),
        'optionVoters.$oldOptionIndex': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local cache immediately
      final updatedOptionVoters = Map<String, List<String>>.from(currentPoll.optionVoters);
      if (updatedOptionVoters.containsKey(oldOptionIndex)) {
        updatedOptionVoters[oldOptionIndex] = updatedOptionVoters[oldOptionIndex]!
            .where((id) => id != userId)
            .toList();
        
        if (updatedOptionVoters[oldOptionIndex]!.isEmpty) {
          updatedOptionVoters.remove(oldOptionIndex);
        }
      }
      
      final updatedVotes = Map<String, String>.from(currentPoll.votes);
      if (!currentPoll.allowMultipleVotes) {
        updatedVotes.remove(userId);
      }
      
      final updatedPoll = currentPoll.copyWith(
        votes: updatedVotes,
        optionVoters: updatedOptionVoters,
        updatedAt: DateTime.now(),
      );
      
      _pollCache[pollId] = updatedPoll;
      _updatePollInLocalLists(updatedPoll);
      
      return true;
    } catch (e) {
      debugPrint('Error removing vote: $e');
      return false;
    }
  }
  
  // NEW: Remove specific vote for multiple votes scenario
  Future<bool> removeSpecificVote({
    required String pollId,
    required String userId,
    required String optionIndex,
  }) async {
    try {
      final currentPoll = getPollById(pollId);
      if (currentPoll == null) return false;
      
      // Check if this is allowed
      if (!currentPoll.allowMultipleVotes) {
        return await removeVote(
          pollId: pollId,
          userId: userId,
          oldOptionIndex: optionIndex,
        );
      }
      
      // For multiple votes, just remove from this specific option
      await _pollService.pollsCollection.doc(pollId).update({
        'optionVoters.$optionIndex': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local cache
      final updatedOptionVoters = Map<String, List<String>>.from(currentPoll.optionVoters);
      if (updatedOptionVoters.containsKey(optionIndex)) {
        updatedOptionVoters[optionIndex] = updatedOptionVoters[optionIndex]!
            .where((id) => id != userId)
            .toList();
        
        if (updatedOptionVoters[optionIndex]!.isEmpty) {
          updatedOptionVoters.remove(optionIndex);
        }
      }
      
      final updatedPoll = currentPoll.copyWith(
        optionVoters: updatedOptionVoters,
        updatedAt: DateTime.now(),
      );
      
      _pollCache[pollId] = updatedPoll;
      _updatePollInLocalLists(updatedPoll);
      
      return true;
    } catch (e) {
      debugPrint('Error removing specific vote: $e');
      return false;
    }
  }
  
  // Helper to update poll in all local lists
  void _updatePollInLocalLists(PollModel updatedPoll) {
    // Update in polls list
    final pollIndex = _polls.indexWhere((p) => p.pollId == updatedPoll.pollId);
    if (pollIndex != -1) {
      _polls[pollIndex] = updatedPoll;
    }
    
    // Update in active polls list
    final activeIndex = _activePolls.indexWhere((p) => p.pollId == updatedPoll.pollId);
    if (activeIndex != -1) {
      _activePolls[activeIndex] = updatedPoll;
    }
    
    // Update in polls needing vote list
    final needingVoteIndex = _pollsNeedingVote.indexWhere((p) => p.pollId == updatedPoll.pollId);
    if (needingVoteIndex != -1) {
      _pollsNeedingVote[needingVoteIndex] = updatedPoll;
    }
    
    notifyListeners();
  }
  
  // Refresh all polls
  Future<void> refreshPolls(String communityId, String userId, {String? programId}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Cancel streams first
      await _pollsSubscription?.cancel();
      await _activePollsSubscription?.cancel();
      await _needingVoteSubscription?.cancel();
      
      // Clear data
      _polls.clear();
      _activePolls.clear();
      _pollsNeedingVote.clear();
      _pollCache.clear();
      
      // Reload fresh data
      await Future.wait([
        loadCommunityPolls(communityId, programId: programId),
        loadPollsNeedingVote(communityId, userId),
      ]);
      
    } catch (e) {
      _error = e.toString();
      debugPrint('Error refreshing polls: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update poll
  Future<bool> updatePoll(PollModel poll) async {
    try {
      // Ensure updatedAt is current
      final pollToUpdate = poll.copyWith(updatedAt: DateTime.now());
      
      await _pollService.updatePoll(pollToUpdate);
      
      // Update local cache immediately for instant UI response
      _pollCache[pollToUpdate.pollId] = pollToUpdate;
      _updatePollInLocalLists(pollToUpdate);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating poll: $e');
      return false;
    }
  }
  
  // Update poll status
  Future<bool> updatePollStatus(String pollId, PollStatus status) async {
    try {
      final poll = getPollById(pollId);
      if (poll == null) return false;
      
      final updatedPoll = poll.copyWith(status: status);
      return await updatePoll(updatedPoll);
    } catch (e) {
      debugPrint('Error updating poll status: $e');
      return false;
    }
  }
  
  // Implement poll result
  Future<bool> implementPoll(String pollId, Map<String, dynamic> resultData) async {
    try {
      final poll = getPollById(pollId);
      if (poll == null) return false;
      
      final updatedPoll = poll.copyWith(
        status: PollStatus.closed,
        isImplemented: true,
        implementedAt: DateTime.now(),
        resultData: resultData,
      );
      
      return await updatePoll(updatedPoll);
    } catch (e) {
      debugPrint('Error implementing poll: $e');
      return false;
    }
  }
  
  // Delete poll
  Future<bool> deletePoll(String pollId) async {
    try {
      await _pollService.deletePoll(pollId);
      
      // Remove from local lists
      _polls.removeWhere((p) => p.pollId == pollId);
      _activePolls.removeWhere((p) => p.pollId == pollId);
      _pollsNeedingVote.removeWhere((p) => p.pollId == pollId);
      _pollCache.remove(pollId);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting poll: $e');
      return false;
    }
  }
  
  // Check if user has voted
  bool hasUserVoted(String pollId, String userId) {
    final poll = getPollById(pollId);
    return poll?.hasUserVoted(userId) ?? false;
  }
  
  // Get user's vote
  String? getUserVote(String pollId, String userId) {
    final poll = getPollById(pollId);
    return poll?.getUserVote(userId);
  }
  
  // NEW: Get all user's votes (for multiple votes)
  List<String> getUserVotes(String pollId, String userId) {
    final poll = getPollById(pollId);
    return poll?.getUserVotes(userId) ?? [];
  }
  
  // NEW: Check if user can change vote
  bool canUserChangeVote(String pollId, String userId) {
    final poll = getPollById(pollId);
    return poll?.canUserChangeVote(userId) ?? true; // Default to true
  }
  
  // NEW: Check if user can vote on poll
  bool canUserVote(String pollId, String userId) {
    final poll = getPollById(pollId);
    return poll?.canUserVote(userId) ?? false;
  }
  
  // Clear all data and subscriptions
  void clear() {
    _polls.clear();
    _activePolls.clear();
    _pollsNeedingVote.clear();
    _pollCache.clear();
    _isLoading = false;
    _error = null;
    
    // Cancel all subscriptions
    _pollsSubscription?.cancel();
    _activePollsSubscription?.cancel();
    _needingVoteSubscription?.cancel();
    
    _pollsSubscription = null;
    _activePollsSubscription = null;
    _needingVoteSubscription = null;
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    // Cancel all subscriptions asynchronously
    Future.wait([
      _pollsSubscription?.cancel(),
      _activePollsSubscription?.cancel(),
      _needingVoteSubscription?.cancel(),
    ].where((future) => future != null).cast<Future>());
    
    clear();
    super.dispose();
  }
}
