import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/polls/providers/poll_provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/polls/models/poll_model.dart';
import 'package:kofund/features/polls/screens/create_poll_screen.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/polls/screens/poll_details_screen.dart';
import 'dart:async';

class PollDashboardWidget extends StatefulWidget {
  final String communityId;
  final bool isAdmin;

  const PollDashboardWidget({
    super.key,
    required this.communityId,
    required this.isAdmin,
  });

  @override
  State<PollDashboardWidget> createState() => _PollDashboardWidgetState();
}

class _PollDashboardWidgetState extends State<PollDashboardWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  StreamSubscription<List<PollModel>>? _activePollsSubscription;
  List<PollModel> _currentActivePolls = [];
  bool _isLoading = true;
  bool _shouldRefresh = false;

  @override
  void initState() {
    super.initState();
    _setupPollStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for when we return from creating/editing a poll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldRefresh) {
        _refreshPolls();
        _shouldRefresh = false;
      }
    });
  }

  void _setupPollStream() {
    final pollProvider = context.read<PollProvider>();
    final authProvider = context.read<AppAuthProvider>();
    
    // Cancel existing subscription
    _activePollsSubscription?.cancel();
    
    // Debug: Print community ID
    debugPrint('Setting up poll stream for community: ${widget.communityId}');
    
    // Set up stream for active polls - DIRECT STREAM ACCESS
    _activePollsSubscription = pollProvider.pollService
        .streamActivePolls(widget.communityId)
        .listen((polls) {
          if (mounted) {
            // Debug: Print received polls
            debugPrint('Received ${polls.length} polls for community ${widget.communityId}');
            for (var poll in polls) {
              debugPrint('Poll: ${poll.title}, Community: ${poll.communityId}, Status: ${poll.status}, Expired: ${poll.isExpired}');
            }
            
            setState(() {
              _currentActivePolls = polls;
              _isLoading = false;
            });
          }
        }, onError: (error) {
          debugPrint('Error in poll stream: $error');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        });
    
    // Also load polls needing vote
    if (authProvider.user != null) {
      pollProvider.loadPollsNeedingVote(widget.communityId, authProvider.user!.uid);
    }
  }

  Future<void> _refreshPolls() async {
    final pollProvider = context.read<PollProvider>();
    final authProvider = context.read<AppAuthProvider>();
    
    setState(() => _isLoading = true);
    
    // Cancel and restart stream
    _activePollsSubscription?.cancel();
    
    // Brief delay to ensure clean restart
    await Future.delayed(const Duration(milliseconds: 100));
    
    _setupPollStream();
    
    // Also refresh provider data
    await pollProvider.refreshPolls(
      widget.communityId, 
      authProvider.user?.uid ?? '',
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _activePollsSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPollDetails(String pollId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PollDetailsScreen(
          pollId: pollId,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  void _createNewPoll() async {
    // Set flag to refresh when we return
    _shouldRefresh = true;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePollScreen(
          communityId: widget.communityId,
        ),
      ),
    );
    
    // Refresh polls when returning from create screen
    if (result == true && mounted) {
      _refreshPolls();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Community Polls",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              Row(
                children: [
                  // Refresh button
                  IconButton(
                    icon: Icon(Icons.refresh,
                        color: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary),
                    onPressed: _refreshPolls,
                    tooltip: 'Refresh polls',
                  ),
                  if (widget.isAdmin)
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary),
                      onPressed: _createNewPoll,
                      tooltip: 'Create new poll',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        _buildPollCarousel(isDarkMode),
      ],
    );
  }

  Widget _buildPollCarousel(bool isDarkMode) {
    final authProvider = context.watch<AppAuthProvider>();
    final pollProvider = context.watch<PollProvider>();

    if (_isLoading) {
      return _buildLoadingSkeleton(isDarkMode);
    }

    // Filter active polls that are not expired
    final activePolls = _currentActivePolls
        .where((poll) => !poll.isExpired && poll.status == PollStatus.active)
        .toList();

    // Debug: Print filtered active polls
    debugPrint('Filtered active polls: ${activePolls.length}');
    for (var poll in activePolls) {
      debugPrint('Active Poll: ${poll.title}, ID: ${poll.pollId}, Community: ${poll.communityId}');
    }

    if (activePolls.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    // Calculate max height needed for all polls
    double maxPollHeight = 0;
    for (var poll in activePolls) {
      final cardHeight = _calculatePollCardHeight(poll);
      if (cardHeight > maxPollHeight) {
        maxPollHeight = cardHeight;
      }
    }
    
    final carouselHeight = (maxPollHeight + 20).clamp(300.0, 600.0);

    return SizedBox(
      height: carouselHeight,
      child: PageView.builder(
        controller: _pageController,
        itemCount: activePolls.length,
        itemBuilder: (context, index) {
          final poll = activePolls[index];
          final canUserVote = pollProvider.canUserVote(poll.pollId, authProvider.user?.uid ?? '');
          final canUserChangeVote = pollProvider.canUserChangeVote(poll.pollId, authProvider.user?.uid ?? '');
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _InstagramPollCard(
              poll: poll,
              isDarkMode: isDarkMode,
              userId: authProvider.user?.uid ?? '',
              canUserVote: canUserVote,
              canUserChangeVote: canUserChangeVote,
              onVote: (optionIndex) => _castVote(poll, optionIndex),
              onViewDetails: () => _navigateToPollDetails(poll.pollId),
            ),
          );
        },
      ),
    );
  }

  double _calculatePollCardHeight(PollModel poll) {
    const double headerHeight = 60.0;
    const double statsHeight = 20.0;
    const double paddingHeight = 32.0;
    const double buttonAreaHeight = 50.0;
    
    final int optionCount = poll.options.length;
    const double singleOptionHeight = 52.0;
    const double spacingBetweenOptions = 8.0;
    
    final double optionsTotalHeight = 
        (optionCount * singleOptionHeight) + 
        ((optionCount - 1) * spacingBetweenOptions);
    
    return headerHeight + statsHeight + paddingHeight + optionsTotalHeight + buttonAreaHeight;
  }

  Widget _buildLoadingSkeleton(bool isDarkMode) {
    return SizedBox(
      height: 350,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    height: 40,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.poll_outlined,
              size: 48,
              color: isDarkMode
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
          const SizedBox(height: 12),
          Text("No Active Polls",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              )),
          const SizedBox(height: 8),
          Text(widget.isAdmin
              ? "Create a poll to gather member opinions"
              : "Check back later for new polls",
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              )),
          if (widget.isAdmin) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createNewPoll,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Create First Poll"),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _castVote(PollModel poll, String optionIndex) async {
    final authProvider = context.read<AppAuthProvider>();
    final pollProvider = context.read<PollProvider>();
    
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login to vote'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Check if user can vote
    if (!pollProvider.canUserVote(poll.pollId, authProvider.user!.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You cannot vote on this poll'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      final success = await pollProvider.castVote(
        pollId: poll.pollId,
        userId: authProvider.user!.uid,
        optionIndex: optionIndex,
      );
      
      if (success) {
        // The stream will automatically update in real-time
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: poll.allowVoteChange 
                ? Text('Vote submitted! You can change it until the poll ends.')
                : Text('Vote submitted! This vote is final and cannot be changed.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit vote'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error casting vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to vote: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Rest of the code remains the same...

// ========== UPDATED InstagramPollCard with Vote Change Support ==========

class _InstagramPollCard extends StatefulWidget {
  final PollModel poll;
  final bool isDarkMode;
  final String userId;
  final bool canUserVote;
  final bool canUserChangeVote;
  final Function(String) onVote;
  final VoidCallback onViewDetails;

  const _InstagramPollCard({
    Key? key,
    required this.poll,
    required this.isDarkMode,
    required this.userId,
    required this.canUserVote,
    required this.canUserChangeVote,
    required this.onVote,
    required this.onViewDetails,
  }) : super(key: key);

  @override
  State<_InstagramPollCard> createState() => __InstagramPollCardState();
}

class __InstagramPollCardState extends State<_InstagramPollCard> with TickerProviderStateMixin {
  StreamSubscription<PollModel?>? _pollSubscription;
  PollModel? _currentPoll;
  bool _isVoting = false;
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, double> _currentPercentages = {};

  @override
  void initState() {
    super.initState();
    _currentPoll = widget.poll;
    _setupPollSubscription();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    final poll = _currentPoll ?? widget.poll;
    final hasVoted = poll.hasUserVoted(widget.userId);
    
    if (hasVoted) {
      for (int i = 0; i < poll.options.length; i++) {
        final optionIndex = i.toString();
        final voteCount = poll.getOptionVoteCount(optionIndex);
        final percentage = poll.totalVotes > 0 ? (voteCount / poll.totalVotes * 100) : 0.0;
        
        _animationControllers[optionIndex] = AnimationController(
          duration: const Duration(milliseconds: 800),
          vsync: this,
        );
        
        _currentPercentages[optionIndex] = percentage;
        
        // Start animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animationControllers[optionIndex]?.forward();
        });
      }
    }
  }

  void _setupPollSubscription() {
    final pollProvider = context.read<PollProvider>();
    
    // Cancel existing subscription
    _pollSubscription?.cancel();
    
    // Subscribe to real-time updates for this specific poll
    _pollSubscription = pollProvider.pollService
        .streamPollById(widget.poll.pollId)
        .listen((updatedPoll) {
          if (mounted && updatedPoll != null) {
            // Animate percentage changes
            _animatePercentageChanges(updatedPoll);
            
            setState(() {
              _currentPoll = updatedPoll;
            });
          }
        }, onError: (error) {
          debugPrint('Error in poll subscription: $error');
        });
  }

  void _animatePercentageChanges(PollModel updatedPoll) {
    final hasVoted = updatedPoll.hasUserVoted(widget.userId);
    
    if (hasVoted) {
      for (int i = 0; i < updatedPoll.options.length; i++) {
        final optionIndex = i.toString();
        final voteCount = updatedPoll.getOptionVoteCount(optionIndex);
        final newPercentage = updatedPoll.totalVotes > 0 
            ? (voteCount / updatedPoll.totalVotes * 100) 
            : 0.0;
        
        // Initialize controller if it doesn't exist
        if (!_animationControllers.containsKey(optionIndex)) {
          _animationControllers[optionIndex] = AnimationController(
            duration: const Duration(milliseconds: 800),
            vsync: this,
          );
        }
        
        final oldPercentage = _currentPercentages[optionIndex] ?? 0.0;
        
        // Only animate if percentage changed
        if ((newPercentage - oldPercentage).abs() > 0.5) {
          _currentPercentages[optionIndex] = newPercentage;
          
          // Reset and animate to new value
          _animationControllers[optionIndex]?.reset();
          _animationControllers[optionIndex]?.forward();
        }
      }
    }
  }

  @override
  void didUpdateWidget(_InstagramPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.poll.pollId != oldWidget.poll.pollId) {
      setState(() {
        _currentPoll = widget.poll;
      });
      _setupPollSubscription();
    }
  }

  @override
  void dispose() {
    _pollSubscription?.cancel();
    // Dispose all animation controllers
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poll = _currentPoll ?? widget.poll;
    final hasVoted = poll.hasUserVoted(widget.userId);
    final daysLeft = poll.endDate.difference(DateTime.now()).inDays;
    final userVotes = poll.getUserVotes(widget.userId);
    
    final cardHeight = _calculateCardHeight(poll);
    
    // Determine if votes are locked
    final votesLocked = hasVoted && !widget.canUserChangeVote;
    
    return Container(
      height: cardHeight,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary).withOpacity(0.12),
                      radius: 16,
                      child: Icon(
                        Icons.poll,
                        color: widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        poll.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Vote lock indicator
                    if (votesLocked && poll.totalVotes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock,
                              size: 10,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Locked',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Days left indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: daysLeft <= 1
                            ? Color(Colors.red.value).withOpacity(0.1)
                            : widget.isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        daysLeft <= 0
                            ? "Ended"
                            : daysLeft == 1
                                ? "1 day"
                                : "$daysLeft days",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: daysLeft <= 1
                              ? Colors.red
                              : widget.isDarkMode
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Poll stats row
                Row(
                  children: [
                    // Poll type indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getPollTypeShortLabel(poll.type),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    
                    if (poll.isAnonymous)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Icon(Icons.visibility_off, size: 12,
                                color: widget.isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                            const SizedBox(width: 2),
                            Text(
                              "Anonymous",
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (poll.allowMultipleVotes)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Icon(Icons.checklist, size: 12,
                                color: widget.isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                            const SizedBox(width: 2),
                            Text(
                              "Multiple",
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!poll.allowVoteChange && hasVoted)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 12,
                                color: Colors.orange),
                            const SizedBox(width: 2),
                            Text(
                              "Final",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      "${poll.totalVotes} votes",
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Options
                Column(
                  children: poll.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final optionIndex = index.toString();
                    final voteCount = poll.getOptionVoteCount(optionIndex);
                    final percentage = poll.totalVotes > 0 
                        ? (voteCount / poll.totalVotes * 100)
                        : 0.0;
                    
                    final isSelected = userVotes.contains(optionIndex);
                    final isWinning = poll.winningOptionIndex == optionIndex;
                    
                    return Padding(
                      padding: EdgeInsets.only(bottom: index < poll.options.length - 1 ? 8 : 0),
                      child: _AnimatedPollOption(
                        option: option,
                        percentage: hasVoted ? percentage : 0,
                        voteCount: hasVoted ? voteCount : 0,
                        totalVotes: poll.totalVotes,
                        isSelected: isSelected,
                        isWinning: isWinning && hasVoted,
                        showResults: hasVoted,
                        isVoting: _isVoting,
                        votesLocked: votesLocked,
                        canUserVote: widget.canUserVote,
                        onTap: () async {
                          if (votesLocked) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Votes are locked for this poll. You cannot change your vote.'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          
                          if (!widget.canUserVote) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('You cannot vote on this poll'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          
                          if (_isVoting) return;
                          
                          // For multiple votes, check if already selected
                          if (poll.allowMultipleVotes && isSelected) {
                            // Allow deselecting if vote changes are allowed
                            if (widget.canUserChangeVote) {
                              setState(() => _isVoting = true);
                              try {
                                final pollProvider = context.read<PollProvider>();
                                await pollProvider.removeSpecificVote(
                                  pollId: poll.pollId,
                                  userId: widget.userId,
                                  optionIndex: optionIndex,
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isVoting = false);
                                }
                              }
                            }
                          } else {
                            // Normal vote
                            if (!hasVoted || widget.canUserChangeVote) {
                              setState(() => _isVoting = true);
                              try {
                                await widget.onVote(optionIndex);
                              } finally {
                                if (mounted) {
                                  setState(() => _isVoting = false);
                                }
                              }
                            }
                          }
                        },
                        isDarkMode: widget.isDarkMode,
                        optionCount: poll.options.length,
                        animationController: _animationControllers[optionIndex],
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
          
          // Poll Details Button - Bottom right
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: widget.onViewDetails,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Poll Details",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
   
        ],
      ),
    );
  }
  
  double _calculateCardHeight(PollModel poll) {
    const double baseHeight = 140.0;
    const double detailsButtonArea = 40.0;
    const double bottomPadding = 20.0;
    
    const double optionHeight = 52.0;
    const double optionSpacing = 8.0;
    
    final double optionsHeight = (poll.options.length * optionHeight) + 
        ((poll.options.length - 1) * optionSpacing);
    
    return baseHeight + optionsHeight + detailsButtonArea + bottomPadding;
  }
  
  String _getPollTypeShortLabel(PollType type) {
    switch (type) {
      case PollType.decision:
        return 'DEC';
      case PollType.suggestion:
        return 'SUG';
      case PollType.planning:
        return 'PLN';
      case PollType.contribution:
        return 'CON';
      case PollType.expenseApproval:
        return 'EXP';
      default:
        return 'POL';
    }
  }
}

// ========== UPDATED AnimatedPollOption Widget with Vote Change Support ==========

class _AnimatedPollOption extends StatefulWidget {
  final String option;
  final double percentage;
  final int voteCount;
  final int totalVotes;
  final bool isSelected;
  final bool isWinning;
  final bool showResults;
  final bool isVoting;
  final bool votesLocked;
  final bool canUserVote;
  final VoidCallback onTap;
  final bool isDarkMode;
  final int optionCount;
  final AnimationController? animationController;

  const _AnimatedPollOption({
    required this.option,
    required this.percentage,
    required this.voteCount,
    required this.totalVotes,
    required this.isSelected,
    required this.isWinning,
    required this.showResults,
    required this.isVoting,
    required this.votesLocked,
    required this.canUserVote,
    required this.onTap,
    required this.isDarkMode,
    required this.optionCount,
    this.animationController,
  });

  @override
  State<_AnimatedPollOption> createState() => __AnimatedPollOptionState();
}

class __AnimatedPollOptionState extends State<_AnimatedPollOption> {
  late Animation<double> _percentageAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animationController != null) {
      _percentageAnimation = Tween<double>(
        begin: 0,
        end: widget.percentage,
      ).animate(CurvedAnimation(
        parent: widget.animationController!,
        curve: Curves.easeOutCubic,
      ));
    }
  }

  @override
  void didUpdateWidget(_AnimatedPollOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationController != null && 
        (widget.percentage != oldWidget.percentage || 
         widget.animationController != oldWidget.animationController)) {
      _percentageAnimation = Tween<double>(
        begin: oldWidget.percentage,
        end: widget.percentage,
      ).animate(CurvedAnimation(
        parent: widget.animationController!,
        curve: Curves.easeOutCubic,
      ));
      
      // Reset and animate if controller changed
      if (widget.animationController != oldWidget.animationController) {
        widget.animationController!.reset();
        widget.animationController!.forward();
      }
    }
  }

 @override
  Widget build(BuildContext context) {
    final bool useCompactMode = widget.optionCount > 4;
    final bool isInteractive = !widget.votesLocked && widget.canUserVote && !widget.isVoting;
    
    return GestureDetector(
      onTap: isInteractive ? widget.onTap : null,
      child: Container(
        height: useCompactMode ? 44.0 : 52.0,
        decoration: BoxDecoration(
          color: widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected
                ? (widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary)
                : (widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: widget.votesLocked && widget.isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Animated progress fill - NO FADE EFFECT
            if (widget.showResults && widget.animationController != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _percentageAnimation,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FractionallySizedBox(
                        widthFactor: _percentageAnimation.value / 100,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.isWinning
                                ? Colors.green.withOpacity(0.15)
                                : (widget.isDarkMode 
                                    ? AppColors.darkPrimary.withOpacity(0.1)
                                    : AppColors.lightPrimary.withOpacity(0.1)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Content with padding
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: useCompactMode ? 6 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Option text with lock icon if locked
                  Expanded(
                    child: Row(
                      children: [
                        if (widget.votesLocked && widget.isSelected)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.orange,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.option,
                            style: TextStyle(
                              fontSize: useCompactMode ? 13 : 14,
                              fontWeight: FontWeight.w500,
                              color: widget.isDarkMode
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Percentage and vote count
                  if (widget.showResults)
                    Row(
                      children: [
                        // Animated percentage text
                        if (widget.animationController != null)
                          AnimatedBuilder(
                            animation: _percentageAnimation,
                            builder: (context, child) {
                              return Text(
                                '${_percentageAnimation.value.toInt()}%',
                                style: TextStyle(
                                  fontSize: useCompactMode ? 12 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isWinning
                                      ? Colors.green
                                      : (widget.isDarkMode 
                                          ? AppColors.darkPrimary 
                                          : AppColors.lightPrimary),
                                ),
                              );
                            },
                          )
                        else
                          Text(
                            '${widget.percentage.toInt()}%',
                            style: TextStyle(
                              fontSize: useCompactMode ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isWinning
                                  ? Colors.green
                                  : (widget.isDarkMode 
                                      ? AppColors.darkPrimary 
                                      : AppColors.lightPrimary),
                            ),
                          ),
                        
                        // Vote count
                        if (widget.voteCount > 0 && !useCompactMode)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '(${widget.voteCount})',
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (widget.isSelected)
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: widget.votesLocked 
                          ? Colors.orange
                          : (widget.isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}