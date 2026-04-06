import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/polls/providers/poll_provider.dart';
import 'package:kofund/features/polls/models/poll_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/polls/screens/create_poll_screen.dart';
import 'dart:async';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class PollDetailsScreen extends StatefulWidget {
  final String pollId;
  final bool isAdmin;

  const PollDetailsScreen({
    super.key,
    required this.pollId,
    required this.isAdmin,
  });

  @override
  State<PollDetailsScreen> createState() => _PollDetailsScreenState();
}

class _PollDetailsScreenState extends State<PollDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  PollModel? _poll;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _loadingVoters = false;
  List<Map<String, dynamic>> _voters = [];
  
  // Stream subscription for real-time updates
  StreamSubscription<DocumentSnapshot>? _pollSubscription;

  @override
  void initState() {
    super.initState();
    _loadPoll();
    _setupPollSubscription();
  }
void _setupPollSubscription() {
  // Access Firestore collection directly
  _pollSubscription = _firestore
      .collection('polls')
      .doc(widget.pollId)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.exists && mounted) {
      setState(() {
        _poll = PollModel.fromFirestore(snapshot);
        
        // Reload voter details if not anonymous
        if (_poll != null && !_poll!.isAnonymous) {
          _loadVoterDetails();
        }
      });
    }
  }, onError: (error) {
    debugPrint('Poll stream error: $error');
  });
}
  Future<void> _loadPoll() async {
    try {
      final pollProvider = context.read<PollProvider>();
      final poll = await pollProvider.getPoll(widget.pollId);
      
      if (mounted) {
        setState(() {
          _poll = poll;
        });
        
        if (poll != null && !poll.isAnonymous) {
          await _loadVoterDetails();
        }
      }
    } catch (e) {
      debugPrint('Error loading poll: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading poll: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVoterDetails() async {
    if (_poll == null) return;
    
    setState(() => _loadingVoters = true);
    
    try {
      final List<Map<String, dynamic>> voters = [];
      
      // Batch fetch users for better performance
      final userPromises = <Future<void>>[];
      
      for (final entry in _poll!.votes.entries) {
        final userId = entry.key;
        final optionIndex = entry.value;
        final option = _poll!.options[int.parse(optionIndex)];
        
        userPromises.add(_firestore
            .collection('users')
            .doc(userId)
            .get()
            .then((userDoc) {
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            voters.add({
              'userId': userId,
              'name': userData['displayName'] ?? userData['email']?.split('@').first ?? 'User',
              'email': userData['email'] ?? 'No email',
              'photoUrl': userData['photoURL'],
              'option': option,
              'optionIndex': optionIndex,
              'timestamp': entry.key, // Using userId as unique key
            });
          }
        }).catchError((error) {
          debugPrint('Error loading user $userId: $error');
        }));
      }
      
      await Future.wait(userPromises);
      
      // Sort by name alphabetically
      voters.sort((a, b) => a['name'].compareTo(b['name']));
      
      if (mounted) {
        setState(() {
          _voters = voters;
          _loadingVoters = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading voter details: $e');
      if (mounted) {
        setState(() => _loadingVoters = false);
      }
    }
  }

  Future<void> _castVote(String optionIndex) async {
    if (_poll == null) return;

    final authProvider = context.read<AppAuthProvider>();
    final pollProvider = context.read<PollProvider>();
    
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to vote')),
      );
      return;
    }
    
    // Check if poll is active
    if (_poll!.status != PollStatus.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This poll is no longer active')),
      );
      return;
    }
    
    // Check if poll has expired
    if (_poll!.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This poll has expired')),
      );
      return;
    }
    
    try {
      final success = await pollProvider.castVote(
        pollId: widget.pollId,
        userId: authProvider.user!.uid,
        optionIndex: optionIndex,
      );
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cast vote. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('Error casting vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _deletePoll() async {
    if (_isDeleting || _poll == null) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Poll'),
        content: const Text('Are you sure you want to delete this poll? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (result != true) return;
    
    setState(() => _isDeleting = true);
    
    try {
      final pollProvider = context.read<PollProvider>();
      final success = await pollProvider.deletePoll(widget.pollId);
      if (!mounted) return;
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll deleted successfully')),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete poll')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting poll: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _editPoll() async {
    if (_poll == null) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePollScreen(
          communityId: _poll!.communityId,
          programId: _poll!.programId,
          pollToEdit: _poll,
          isEditing: true,
        ),
      ),
    );
    
    // Reload poll after editing
    if (mounted) {
      await _loadPoll();
    }
  }

  Future<void> _closePoll() async {
    if (_poll == null) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Poll'),
        content: const Text('Are you sure you want to close this poll? Users will not be able to vote anymore.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    
    if (result != true) return;
    
    try {
      final pollProvider = context.read<PollProvider>();
      final success = await pollProvider.updatePollStatus(
        widget.pollId,
        PollStatus.closed,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll closed successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error closing poll: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _reopenPoll() async {
    if (_poll == null) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Poll'),
        content: const Text('Are you sure you want to reopen this poll? Users will be able to vote again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    
    if (result != true) return;
    
    try {
      final pollProvider = context.read<PollProvider>();
      final success = await pollProvider.updatePollStatus(
        widget.pollId,
        PollStatus.active,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll reopened successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error reopening poll: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showVoterDetails(String voterId, String voterName, String option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voter Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $voterName'),
            const SizedBox(height: 8),
            Text('Vote: $option'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AppAuthProvider>();
    final hasVoted = _poll?.hasUserVoted(authProvider.user?.uid ?? '') ?? false;

    return GradientSheetScaffold(
      title: 'Poll Details',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.isAdmin && _poll != null && !_isLoading)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'edit') {
                _editPoll();
              } else if (value == 'close' && _poll!.status == PollStatus.active) {
                _closePoll();
              } else if (value == 'reopen' && _poll!.status == PollStatus.closed) {
                _reopenPoll();
              } else if (value == 'delete') {
                _deletePoll();
              }
            },
            itemBuilder: (context) => [
              if (_poll!.status == PollStatus.active)
                const PopupMenuItem(
                  value: 'close',
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock, size: 20),
                      SizedBox(width: 8),
                      Text('Close Poll'),
                    ],
                  ),
                ),
              if (_poll!.status == PollStatus.closed)
                const PopupMenuItem(
                  value: 'reopen',
                  child: Row(
                    children: [
                      Icon(Icons.lock_open, size: 20),
                      SizedBox(width: 8),
                      Text('Reopen Poll'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Poll'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Delete Poll',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
      body: _isLoading
          ? _buildLoadingState(isDarkMode)
          : _poll == null
              ? _buildErrorState(isDarkMode)
              : _buildPollDetails(isDarkMode, hasVoted, authProvider),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading poll...',
            style: TextStyle(
              color: isDarkMode
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDarkMode ? AppColors.darkError : AppColors.lightError,
          ),
          const SizedBox(height: 16),
          Text(
            'Poll not found',
            style: TextStyle(
              fontSize: 18,
              color: isDarkMode
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildPollDetails(bool isDarkMode, bool hasVoted, AppAuthProvider authProvider) {
    final poll = _poll!;
    final daysLeft = poll.endDate.difference(DateTime.now()).inDays;
    final isExpired = poll.isExpired;
    final isClosed = poll.status == PollStatus.closed;
    final canVote = !hasVoted && !isClosed && !isExpired && poll.status == PollStatus.active;
    final currentUserId = authProvider.user?.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll Status Banner
          if (isClosed || isExpired)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isClosed
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isClosed ? Colors.orange : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isClosed ? Icons.lock_clock : Icons.error_outline,
                    color: isClosed ? Colors.orange : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isClosed
                          ? 'This poll is closed'
                          : 'This poll has expired',
                      style: TextStyle(
                        color: isClosed ? Colors.orange : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Poll Header
          Card(
            color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            (isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                        radius: 20,
                        child: Icon(
                          Icons.poll,
                          color: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              poll.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getPollTypeLabel(poll.type),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (poll.description.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDarkMode
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  
                  // Poll Stats
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatChip(
                        Icons.people,
                        '${poll.totalVotes} ${poll.totalVotes == 1 ? 'vote' : 'votes'}',
                        isDarkMode,
                      ),
                      _buildStatChip(
                        Icons.timer,
                        daysLeft <= 0
                            ? "Ended"
                            : daysLeft == 1
                                ? "1 day left"
                                : "$daysLeft days left",
                        isDarkMode,
                        color: daysLeft <= 1 ? Colors.red : null,
                      ),
                      if (poll.isAnonymous)
                        _buildStatChip(
                          Icons.visibility_off,
                          'Anonymous',
                          isDarkMode,
                        ),
                      if (poll.allowMultipleVotes)
                        _buildStatChip(
                          Icons.checklist,
                          'Multiple votes',
                          isDarkMode,
                        ),
                      if (poll.minParticipationPercent != null)
                        _buildStatChip(
                          Icons.percent,
                          '${poll.minParticipationPercent}% min',
                          isDarkMode,
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Creation Info
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Created ${_formatTimeAgo(poll.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  
                  if (poll.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Last updated ${_formatTimeAgo(poll.updatedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Voting Instructions
          if (canVote)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
color: Colors.green.withValues(alpha: 0.1),                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap an option below to vote. You can change your vote until the poll closes.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          
          // Poll Options
          Text(
            'Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          ...poll.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final optionIndex = index.toString();
            final voteCount = poll.getOptionVoteCount(optionIndex);
            final percentage = poll.totalVotes > 0 
                ? (voteCount / poll.totalVotes * 100)
                : 0.0;
            
            final userVote = poll.getUserVote(authProvider.user?.uid ?? '');
            final isSelected = userVote == optionIndex;
            final isWinning = poll.winningOptionIndex == optionIndex && hasVoted && poll.totalVotes > 0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PollOptionDetail(
                option: option,
                percentage: hasVoted || isClosed || isExpired ? percentage : 0,
                voteCount: voteCount,
                totalVotes: poll.totalVotes,
                isSelected: isSelected,
                isWinning: isWinning,
                showResults: hasVoted || isClosed || isExpired,
                onTap: canVote ? () => _castVote(optionIndex) : null,
                isDarkMode: isDarkMode,
                isClosed: isClosed || isExpired,
              ),
            );
          }),
          
          // Vote Status
          if (!canVote && poll.totalVotes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                'Total votes: ${poll.totalVotes}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          
          // Winning Option
          if (hasVoted && poll.totalVotes > 0 && poll.winningOptionIndex != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
color: Colors.green.withValues(alpha: 0.1),                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Winning option: ${poll.options[int.parse(poll.winningOptionIndex!)]}',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Voters List (if not anonymous)
          if (!poll.isAnonymous && poll.totalVotes > 0)
            _buildVotersList(isDarkMode),
          
          const SizedBox(height: 32),
          
          // Admin Actions
          if (widget.isAdmin)
            _buildAdminActions(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, bool isDarkMode, {Color? color}) {
    return Chip(
      avatar: Icon(
        icon,
        size: 14,
        color: color ?? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
      label: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color ?? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ),
      backgroundColor: color?.withValues(alpha: 0.1) ??
          (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
      side: BorderSide(
        color: color?.withValues(alpha: 0.3) ??
            (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildVotersList(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Voters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text('${_poll!.totalVotes}'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (_loadingVoters)
          Center(
            child: CircularProgressIndicator(
              color: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
          )
        else if (_voters.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No voter information available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3,
            ),
            itemCount: _voters.length,
            itemBuilder: (context, index) {
              final voter = _voters[index];
              return GestureDetector(
                onTap: () => _showVoterDetails(
                  voter['userId'],
                  voter['name'],
                  voter['option'],
                ),
                child: Card(
                  color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      radius: 16,
                      child: voter['photoUrl'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                voter['photoUrl'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              voter['name'].substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    title: Text(
                      voter['name'],
                      style: TextStyle(
                        fontSize: 13,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    subtitle: Text(
                      voter['option'],
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAdminActions(bool isDarkMode) {
    return Card(
      color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            if (_poll!.status == PollStatus.active)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _closePoll,
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Close Poll'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
            
            if (_poll!.status == PollStatus.closed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _reopenPoll,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Reopen Poll'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _editPoll,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Poll'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : _deletePoll,
                icon: _isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete),
                label: _isDeleting
                    ? const Text('Deleting...')
                    : const Text('Delete Poll'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPollTypeLabel(PollType type) {
    switch (type) {
      case PollType.decision:
        return "Decision Poll";
      case PollType.suggestion:
        return "Suggestion Poll";
      case PollType.planning:
        return "Planning Poll";
      case PollType.contribution:
        return "Contribution Poll";
      case PollType.expenseApproval:
        return "Expense Approval Poll";
      default:
        return "Poll";
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class _PollOptionDetail extends StatelessWidget {
  final String option;
  final double percentage;
  final int voteCount;
  final int totalVotes;
  final bool isSelected;
  final bool isWinning;
  final bool showResults;
  final VoidCallback? onTap;
  final bool isDarkMode;
  final bool isClosed;

  const _PollOptionDetail({
    required this.option,
    required this.percentage,
    required this.voteCount,
    required this.totalVotes,
    required this.isSelected,
    required this.isWinning,
    required this.showResults,
    this.onTap,
    required this.isDarkMode,
    required this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary)
                : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isWinning
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: (isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Your vote',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (showResults)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isWinning
                          ? Colors.green.withValues(alpha: 0.2)
                          : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isWinning
                            ? Colors.green
                            : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ),
                if (onTap != null && !showResults && !isClosed)
                  Icon(
                    Icons.check_circle_outline,
                    color: (isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary),
                    size: 24,
                  ),
              ],
            ),
            
            if (showResults) ...[
              const SizedBox(height: 12),
              
              // Progress bar with count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      // Background
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.darkProgressBackground
                              : AppColors.lightProgressBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      
                      // Progress
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        height: 8,
                        width: double.infinity,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isWinning
                                  ? Colors.green
                                  : (isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$voteCount ${voteCount == 1 ? 'vote' : 'votes'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (totalVotes > 0)
                        Text(
                          '${(voteCount / totalVotes * 100).toStringAsFixed(1)}% of total',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

